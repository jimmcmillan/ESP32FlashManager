// =============================================================================
// DeviceConfig.swift
// ESP32 Flash Manager
// =============================================================================
//
// PURPOSE
// -------
// Defines the Swift data models that represent a device configuration file.
// One JSON config file exists per supported device, stored in the app bundle
// under Resources/devices/. This file defines the structs that those JSON
// files decode into.
//
// RELATIONSHIP TO OTHER FILES
// ---------------------------
// - DeviceConfig is loaded by FlashViewModel when a device is connected.
// - The loaded config populates the region list in the sidebar and detail panels.
// - ContentView uses DeviceConfig and FlashRegion to build the UI.
//
// CONFIG FILE LOCATION
// --------------------
// Device config JSON files live in the app bundle at:
//   ESP32FlashManager.app/Contents/Resources/devices/<device_id>.json
//
// ADDING A NEW DEVICE
// -------------------
// 1. Create a new JSON file following the format defined by DeviceConfig.
// 2. Add it to the Xcode project under a "devices" group.
// 3. Make sure it is included in the Copy Bundle Resources build phase.
// 4. The app will find it automatically at runtime.
//
// JSON FORMAT EXAMPLE
// -------------------
// See sparkfun_thing_plus_esp32.json for a complete working example.
//
// =============================================================================

import Foundation

// =============================================================================
// MARK: - DeviceConfig
// =============================================================================
// Top-level model representing a complete device configuration file.
// Decoded directly from JSON using Swift's Codable protocol.

struct DeviceConfig: Codable, Identifiable {

    // Unique identifier for this config — matches the JSON filename.
    // e.g. "sparkfun_thing_plus_esp32"
    var id: String { device.id }

    // Device identity and hardware specifications.
    let device: DeviceInfo

    // Ordered list of flash regions defined for this device.
    // The order here determines the order they appear in the UI.
    let regions: [FlashRegion]
}

// =============================================================================
// MARK: - DeviceInfo
// =============================================================================
// Hardware identity information for a device.
// Used for auto-detection (matching chip model and flash size) and display.

struct DeviceInfo: Codable {

    // Unique string identifier for this device.
    // Must match the JSON filename (without extension).
    // e.g. "sparkfun_thing_plus_esp32"
    let id: String

    // Human-readable display name shown in the UI.
    // e.g. "SparkFun Thing Plus ESP32 WROOM"
    let name: String

    // Optional longer description shown in the Device Info panel.
    let description: String?

    // The ESP32 chip model string as reported by esptool chip_id.
    // Used for auto-detection when a device is connected.
    // e.g. "ESP32-D0WD-V3"
    let chipModel: String

    // Total flash size in bytes.
    // Used as a secondary auto-detection criterion alongside chipModel.
    // 16 MB = 16777216 bytes
    let flashSize: Int

    // Maps JSON snake_case keys to Swift camelCase property names.
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case chipModel   = "chip_model"
        case flashSize   = "flash_size"
    }
}

// =============================================================================
// MARK: - FlashRegion
// =============================================================================
// Represents a single named flash memory region on the device.
// Each region has a fixed address, size, and set of permitted operations.

struct FlashRegion: Codable, Identifiable, Hashable {

    // Unique identifier for this region within the device config.
    // e.g. "firmware", "samples", "bootloader"
    let id: String

    // Human-readable name shown in the UI.
    // e.g. "Firmware (app0)", "Sample Data", "Bootloader"
    let name: String

    // Flash start address as a hex string.
    // Stored as a string in JSON to preserve hex notation.
    // e.g. "0x10000"
    // Use the computed property `addressValue` to get the UInt32 value.
    let address: String

    // Region size in bytes.
    // e.g. 2097152 = 2 MB
    let size: Int

    // List of operations permitted on this region.
    // Valid values: "read", "write", "erase"
    // Regions with only ["read"] will show only a Read button in the UI.
    // Regions with ["read", "write", "erase"] show all three buttons.
    let operations: [String]

    // Optional human-readable description shown in the detail panel.
    let description: String?

    // -------------------------------------------------------------------------
    // MARK: Computed Properties
    // -------------------------------------------------------------------------

    // Parses the hex address string and returns it as a UInt32.
    // Returns 0 if the address string is malformed.
    // Used when constructing esptool command arguments.
    var addressValue: UInt32 {
        let cleaned = address.replacingOccurrences(of: "0x", with: "")
                             .replacingOccurrences(of: "0X", with: "")
        return UInt32(cleaned, radix: 16) ?? 0
    }

    // Returns the address formatted as a zero-padded 8-digit hex string.
    // e.g. "0x00010000"
    // Used for display in the UI.
    var addressFormatted: String {
        return String(format: "0x%08X", addressValue)
    }

    // Returns the end address of this region (start + size).
    // e.g. if address = 0x10000 and size = 2097152, end = 0x210000
    var endAddress: UInt32 {
        return addressValue + UInt32(size)
    }

    // Returns the end address formatted as a zero-padded hex string.
    var endAddressFormatted: String {
        return String(format: "0x%08X", endAddress)
    }

    // Returns the size as a human-readable string.
    // e.g. 2097152 → "2048 KB", 16777216 → "16 MB"
    var sizeFormatted: String {
        if size >= 1_048_576 {
            let mb = size / 1_048_576
            return "\(mb) MB"
        } else {
            let kb = size / 1024
            return "\(kb) KB"
        }
    }

    // Returns true if the "read" operation is permitted on this region.
    var canRead: Bool { operations.contains("read") }

    // Returns true if the "write" operation is permitted on this region.
    var canWrite: Bool { operations.contains("write") }

    // Returns true if the "erase" operation is permitted on this region.
    var canErase: Bool { operations.contains("erase") }

    // Returns a short permissions badge string for display in the UI.
    // e.g. "read / write / erase" or "read only"
    var permissionsBadge: String {
        if canRead && canWrite && canErase {
            return "read / write / erase"
        } else if canRead && canWrite {
            return "read / write"
        } else if canRead {
            return "read only"
        } else {
            return "no access"
        }
    }
}

// =============================================================================
// MARK: - DeviceConfigLoader
// =============================================================================
// Utility struct for finding and loading device config files from the app bundle.

struct DeviceConfigLoader {

    // Loads all device config JSON files found in the app bundle's
    // Resources/devices/ directory.
    // Returns an empty array if the directory doesn't exist or no files are found.
    static func loadAll() -> [DeviceConfig] {
        let decoder = JSONDecoder()

        guard let urls = Bundle.main.urls(
            forResourcesWithExtension: "json",
            subdirectory: nil
        ) else {
            print("DeviceConfigLoader: no JSON files found in bundle.")
            return []
        }

        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else {
                print("DeviceConfigLoader: could not read \(url.lastPathComponent)")
                return nil
            }
            guard let config = try? decoder.decode(DeviceConfig.self, from: data) else {
                print("DeviceConfigLoader: could not decode \(url.lastPathComponent)")
                return nil
            }
            return config
        }
    }

    // Attempts to find a device config matching the given chip model and flash size.
    // Used during auto-detection when a device is connected.
    // Returns nil if no matching config is found — the user will be prompted
    // to select a config manually.
    static func find(chipModel: String, flashSize: Int, in configs: [DeviceConfig]) -> DeviceConfig? {
        return configs.first { config in
            config.device.chipModel.lowercased() == chipModel.lowercased() &&
            config.device.flashSize == flashSize
        }
    }
}
