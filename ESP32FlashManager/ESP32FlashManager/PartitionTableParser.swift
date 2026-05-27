// =============================================================================
// PartitionTableParser.swift
// ESP32 Flash Manager
// =============================================================================
//
// PURPOSE
// -------
// Parses the binary partition table read directly from an ESP32 device's
// flash memory at address 0x8000.
//
// The partition table is 4096 bytes (one flash sector). It contains up to
// 95 partition entries of 32 bytes each, followed by an MD5 checksum entry.
//
// PARTITION ENTRY FORMAT (32 bytes)
// ----------------------------------
//   Bytes 00-01  Magic       0xAA 0x50 — identifies a valid entry
//   Byte  02     Type        0x00 = app, 0x01 = data, other = custom
//   Byte  03     SubType     Depends on type (see SubType enum below)
//   Bytes 04-07  Offset      Start address in flash (uint32, little-endian)
//   Bytes 08-11  Size        Size in bytes (uint32, little-endian)
//   Bytes 12-27  Label       Partition name (16 bytes, null-padded ASCII)
//   Bytes 28-31  Flags       Bit 0 = encrypted. Usually 0x00000000.
//
// MD5 ENTRY
// ---------
// The last entry in the table is a special MD5 checksum entry identified
// by the magic bytes 0xEB 0xEB instead of 0xAA 0x50. We skip this entry.
//
// USAGE
// -----
//   let data = // 4096 bytes read from 0x8000
//   let result = PartitionTableParser.parse(data: data)
//   if result.isValid {
//       for partition in result.partitions {
//           print("\(partition.label) at 0x\(String(partition.offset, radix: 16))")
//       }
//   }
//
// RELATIONSHIP TO OTHER FILES
// ---------------------------
// - FlashViewModel calls this after reading 0x8000 from the device
// - The parsed partitions are converted to FlashRegion objects
// - DeviceConfig.swift merges these with the JSON config overlay
//
// =============================================================================

import Foundation

// =============================================================================
// MARK: - ParsedPartition
// =============================================================================
// Represents a single partition entry parsed from the binary table.
// This is an intermediate representation — it gets converted to FlashRegion
// after optional merging with the JSON config overlay.

struct ParsedPartition {

    // Raw fields from the binary entry
    let type: UInt8
    let subType: UInt8
    let offset: UInt32
    let size: UInt32
    let label: String
    let flags: UInt32

    // -------------------------------------------------------------------------
    // MARK: Computed Properties
    // -------------------------------------------------------------------------

    // Human-readable type name
    var typeName: String {
        switch type {
        case 0x00: return "app"
        case 0x01: return "data"
        default:   return String(format: "0x%02X", type)
        }
    }

    // Human-readable subtype name
    var subTypeName: String {
        if type == 0x00 {
            // App subtypes
            switch subType {
            case 0x00: return "factory"
            case 0x10: return "ota_0"
            case 0x11: return "ota_1"
            case 0x12: return "ota_2"
            case 0x13: return "ota_3"
            case 0x20: return "test"
            default:   return String(format: "0x%02X", subType)
            }
        } else if type == 0x01 {
            // Data subtypes
            switch subType {
            case 0x00: return "otadata"
            case 0x01: return "phy"
            case 0x02: return "nvs"
            case 0x03: return "coredump"
            case 0x04: return "nvs_keys"
            case 0x05: return "efuse_em"
            case 0x80: return "esphttpd"
            case 0x81: return "fat"
            case 0x82: return "spiffs"
            case 0x83: return "littlefs"
            default:   return String(format: "0x%02X", subType)
            }
        }
        return String(format: "0x%02X", subType)
    }

    // Whether this is an app partition
    var isApp: Bool { type == 0x00 }

    // Whether this is a data partition
    var isData: Bool { type == 0x01 }

    // End address of this partition
    var endOffset: UInt32 { offset + size }

    // Size as human-readable string
    var sizeFormatted: String {
        if size >= 1_048_576 {
            return "\(size / 1_048_576) MB"
        } else {
            return "\(size / 1024) KB"
        }
    }

    // Default permitted operations based on partition type.
    // App partitions: read/write/erase (firmware updates)
    // Data partitions: read/write/erase
    // We don't restrict anything here — the JSON config overlay can
    // restrict operations on sensitive partitions like bootloader.
    var defaultOperations: [String] {
        // Bootloader and partition table are read-only —
        // writing wrong data to these addresses bricks the device.
        if label == "bootloader" || label == "partition_table" {
            return ["read"]
        }
        return ["read", "write", "erase"]
    }

    // Convert to a FlashRegion for use in the app UI.
    // Uses the partition label as the region ID and a capitalised version
    // as the display name. The JSON config overlay can override both.
    func toFlashRegion() -> FlashRegion {
        // Build a human-readable name from the label and subtype
        let displayName = humanReadableName()

        return FlashRegion(
            id: label.lowercased().trimmingCharacters(in: .whitespaces),
            name: displayName,
            address: String(format: "0x%X", offset),
            size: Int(size),
            operations: defaultOperations,
            description: nil // "\(subTypeName) partition — \(sizeFormatted) at \(String(format: "0x%X", offset))"
        )
    }

    // Generates a human-readable display name from the partition label and type.
    private func humanReadableName() -> String {
        let trimmed = label.trimmingCharacters(in: .whitespaces)

        // Map common partition labels to friendly names
        switch trimmed.lowercased() {
        case "factory":  return "Firmware (factory)"
        case "ota_0":    return "Firmware (OTA slot 0)"
        case "ota_1":    return "Firmware (OTA slot 1)"
        case "ota_2":    return "Firmware (OTA slot 2)"
        case "nvs":      return "NVS Storage"
        case "nvs0":     return "NVS Storage (boot)"
        case "nbkp":     return "NVS Backup"
        case "otadata":  return "OTA Data"
        case "partition_table": return "Partition Table"
        case "phy_init": return "PHY Init Data"
        case "spiffs":   return "SPIFFS"
        case "littlefs": return "LittleFS"
        case "fat":      return "FAT Filesystem"
        case "coredump": return "Core Dump"
        case "config":   return "Device Config"
        case "app0":     return "Firmware (app0)"
        case "app1":     return "Firmware (app1)"
        default:
            // Capitalise the label as-is
            return trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        }
    }
}

// =============================================================================
// MARK: - PartitionTableResult
// =============================================================================
// The result of parsing a partition table binary.

struct PartitionTableResult {

    // Whether the binary contained a valid partition table
    let isValid: Bool

    // Error message if parsing failed
    let error: String?

    // Parsed partition entries (empty if isValid is false)
    let partitions: [ParsedPartition]

    // Number of bytes parsed
    let bytesRead: Int

    // Whether an MD5 checksum entry was found (indicates a complete table)
    let hasMD5: Bool
}

// =============================================================================
// MARK: - PartitionTableParser
// =============================================================================

struct PartitionTableParser {

    // Magic bytes identifying a valid partition entry
    static let entryMagic: [UInt8] = [0xAA, 0x50]

    // Magic bytes identifying the MD5 checksum entry (end of table marker)
    static let md5Magic: [UInt8] = [0xEB, 0xEB]

    // Size of each partition entry in bytes
    static let entrySize = 32

    // Maximum number of partition entries (excluding MD5 entry)
    static let maxEntries = 95

    // ==========================================================================
    // MARK: - Main Parse Function
    // ==========================================================================

    // Parses a binary partition table read from flash address 0x8000.
    // data: the raw bytes read from the device (should be 4096 bytes)
    // Returns a PartitionTableResult with all valid entries found.
    static func parse(data: Data) -> PartitionTableResult {

        guard data.count >= entrySize else {
            return PartitionTableResult(
                isValid: false,
                error: "Data too short — expected at least \(entrySize) bytes, got \(data.count)",
                partitions: [],
                bytesRead: data.count,
                hasMD5: false
            )
        }

        var partitions: [ParsedPartition] = []
        var hasMD5 = false
        var offset = 0

        // Walk through the data in 32-byte chunks
        while offset + entrySize <= data.count && partitions.count < maxEntries {

            let entryData = data[offset..<(offset + entrySize)]
            let bytes = Array(entryData)

            // Check for MD5 entry (end of table marker)
            if bytes[0] == md5Magic[0] && bytes[1] == md5Magic[1] {
                hasMD5 = true
                break
            }

            // Check for valid partition entry magic
            if bytes[0] == entryMagic[0] && bytes[1] == entryMagic[1] {
                if let partition = parseEntry(bytes: bytes) {
                    partitions.append(partition)
                }
            } else if bytes.allSatisfy({ $0 == 0xFF }) {
                // All 0xFF = blank flash, end of table
                break
            }
            // Any other magic bytes = skip (unknown entry type)

            offset += entrySize
        }

        if partitions.isEmpty {
            return PartitionTableResult(
                isValid: false,
                error: "No valid partition entries found. The device may not have a standard ESP32 partition table at 0x8000.",
                partitions: [],
                bytesRead: data.count,
                hasMD5: hasMD5
            )
        }

        // Always prepend the two fixed system regions.
        // These exist at hardcoded addresses on all ESP32 devices and are
        // never listed in the partition table itself.
        let bootloader = ParsedPartition(
            type: 0xFF,
            subType: 0xFF,
            offset: 0x1000,
            size: 28672,    // 28 KB — typical ESP32 bootloader size
            label: "bootloader",
            flags: 0
        )

        let partitionTable = ParsedPartition(
            type: 0xFF,
            subType: 0xFF,
            offset: 0x8000,
            size: 4096,     // 4 KB — one sector
            label: "partition_table",
            flags: 0
        )

        let allPartitions = [bootloader, partitionTable] + partitions

        return PartitionTableResult(
            isValid: true,
            error: nil,
            partitions: allPartitions,
            bytesRead: data.count,
            hasMD5: hasMD5
        )
    }

    // ==========================================================================
    // MARK: - Entry Parser
    // ==========================================================================

    // Parses a single 32-byte partition entry.
    // Returns nil if the entry is malformed.
    private static func parseEntry(bytes: [UInt8]) -> ParsedPartition? {

        guard bytes.count >= entrySize else { return nil }

        // Type (byte 2)
        let type = bytes[2]

        // SubType (byte 3)
        let subType = bytes[3]

        // Offset (bytes 4-7, little-endian uint32)
        let offset = readUInt32LE(bytes: bytes, at: 4)

        // Size (bytes 8-11, little-endian uint32)
        let size = readUInt32LE(bytes: bytes, at: 8)

        // Sanity check — offset and size must be non-zero
        guard offset > 0 || size > 0 else { return nil }

        // Label (bytes 12-27, null-terminated ASCII string)
        let labelBytes = bytes[12..<28]
        let label = parseLabel(bytes: Array(labelBytes))

        // Flags (bytes 28-31, little-endian uint32)
        let flags = readUInt32LE(bytes: bytes, at: 28)

        return ParsedPartition(
            type: type,
            subType: subType,
            offset: offset,
            size: size,
            label: label,
            flags: flags
        )
    }

    // ==========================================================================
    // MARK: - Helper Functions
    // ==========================================================================

    // Reads a little-endian uint32 from a byte array at the given index.
    private static func readUInt32LE(bytes: [UInt8], at index: Int) -> UInt32 {
        guard index + 3 < bytes.count else { return 0 }
        return UInt32(bytes[index]) |
               UInt32(bytes[index + 1]) << 8 |
               UInt32(bytes[index + 2]) << 16 |
               UInt32(bytes[index + 3]) << 24
    }

    // Parses a null-terminated ASCII label from a byte array.
    // Strips null bytes and non-printable characters.
    private static func parseLabel(bytes: [UInt8]) -> String {
        var result = ""
        for byte in bytes {
            if byte == 0x00 { break }
            if byte >= 0x20 && byte < 0x7F {
                result.append(Character(UnicodeScalar(byte)))
            }
        }
        return result
    }
}

// =============================================================================
// MARK: - DeviceConfigLoader Extension
// =============================================================================
// Extends DeviceConfigLoader with a function to merge detected partitions
// with an optional JSON config overlay.

extension DeviceConfigLoader {

    // Merges a list of detected partitions with an optional JSON config.
    //
    // The merge strategy:
    // 1. Start with all detected partitions converted to FlashRegion
    // 2. For each detected region, check if the JSON config has a matching
    //    region with the same ID or address — if so, use the JSON name,
    //    description, and operations instead of the defaults
    // 3. Add any JSON regions that weren't detected (e.g. raw flash regions
    //    like the T-APE samples partition at 0x400000 which lives outside
    //    the partition table)
    //
    // This gives us the best of both worlds:
    //   - Accurate addresses from the actual device
    //   - Human-readable names and descriptions from the JSON config
    //   - Extra regions (like samples) from the JSON config
    static func merge(
        detected: [ParsedPartition],
        config: DeviceConfig?
    ) -> [FlashRegion] {

        var regions: [FlashRegion] = []

        // Convert detected partitions to FlashRegion, applying JSON overrides
        for partition in detected {
            var region = partition.toFlashRegion()

            // Check if the JSON config has a matching region
            if let config = config {
                if let jsonRegion = config.regions.first(where: { jsonR in
                    // Match by ID (label) or by address
                    jsonR.id == region.id ||
                    jsonR.addressValue == partition.offset
                }) {
                    // Apply JSON overrides — keep detected address and size,
                    // but use JSON name, description, and operations
                    region = FlashRegion(
                        id: jsonRegion.id,
                        name: jsonRegion.name,
                        address: region.address,  // Keep detected address
                        size: region.size,          // Keep detected size
                        operations: jsonRegion.operations,
                        description: jsonRegion.description
                    )
                }
            }

            regions.append(region)
        }

        // Add any JSON regions that weren't detected
        // These are regions that exist outside the partition table
        // (e.g. T-APE samples at 0x400000, bootloader at 0x1000)
        if let config = config {
            for jsonRegion in config.regions {
                let alreadyPresent = regions.contains { region in
                    region.id == jsonRegion.id ||
                    region.addressValue == jsonRegion.addressValue
                }
                if !alreadyPresent {
                    regions.append(jsonRegion)
                }
            }
        }

        // Sort regions by address for consistent display
        regions.sort { $0.addressValue < $1.addressValue }

        return regions
    }
}
