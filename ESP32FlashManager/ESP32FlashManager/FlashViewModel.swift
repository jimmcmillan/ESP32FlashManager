// =============================================================================
// FlashViewModel.swift
// ESP32 Flash Manager
// =============================================================================
//
// PURPOSE
// -------
// The central observable class for the ESP32 Flash Manager app.
// Manages all state and logic for:
//   - Serial port scanning and selection
//   - Device auto-detection via esptool
//   - Device config loading and matching
//   - Flash read, write, and erase operations
//   - esptool subprocess management and output streaming
//   - Progress tracking and error handling
//
// RELATIONSHIP TO OTHER FILES
// ---------------------------
// - DeviceConfig.swift defines the data models this class works with.
// - ContentView.swift observes this class and renders the UI from its state.
// - esptool is the binary this class invokes as a subprocess.
//
// ESPTOOL USAGE
// -------------
// All flash operations are performed by launching esptool as a
// subprocess. The binary must be in the app bundle's Resources folder.
// esptool cannot be run directly from Terminal when signed this way —
// it must be launched from within the signed app bundle.
//
// PORT MANAGEMENT
// ---------------
// The serial port must not be held open by any other process (e.g. Arduino
// IDE Serial Monitor) when esptool runs. The app warns the user if the port
// appears busy.
//
// =============================================================================

import Foundation
import Combine
import AppKit

// =============================================================================
// MARK: - OperationType
// =============================================================================
// Represents the type of flash operation currently being performed.
// Used to determine which UI panel to show and how to interpret progress.

enum OperationType {
    case flash      // Writing a .bin file to a flash address
    case read       // Reading a flash region to a file
    case erase      // Erasing a flash region
    case detect     // Running chip_id to detect the connected device
    case none       // No operation in progress
}

// =============================================================================
// MARK: - OperationState
// =============================================================================
// Represents the current state of a flash operation.

enum OperationState {
    case idle       // No operation running
    case running    // Operation in progress
    case success    // Operation completed successfully
    case failure    // Operation failed — see errorMessage for details
}

// =============================================================================
// MARK: - ConsoleMessage
// =============================================================================
// A single line of console output with a semantic type for colour coding.

struct ConsoleMessage: Identifiable {
    let id = UUID()
    let text: String
    let type: MessageType

    enum MessageType {
        case info       // Blue — informational esptool output
        case success    // Green — successful operations, hash verified
        case warning    // Amber — warnings, erase operations
        case error      // Red — errors and failures
        case dim        // Grey — metadata (chip info, MAC, crystal freq)
        case progress   // Teal — write progress bars
        case normal     // Default — general output
    }
}

// =============================================================================
// MARK: - FlashViewModel
// =============================================================================

@MainActor
class FlashViewModel: ObservableObject {
    
    // -------------------------------------------------------------------------
    // MARK: Published State — Device
    // -------------------------------------------------------------------------
    
    // All device configs loaded from the bundle's devices/ folder.
    @Published var availableConfigs: [DeviceConfig] = []
    
    // The currently selected device config.
    // Set automatically during auto-detection, or manually by the user.
    @Published var selectedConfig: DeviceConfig?
    
    // Detected chip model string from esptool (e.g. "ESP32-D0WD-V3")
    @Published var detectedChipModel: String = ""
    
    // Detected flash size in bytes from esptool
    @Published var detectedFlashSize: Int = 0
    
    // Detected MAC address from esptool
    @Published var detectedMAC: String = ""
    
    // Detected chip revision from esptool (e.g. "v3.1")
    @Published var detectedRevision: String = ""
    
    // Whether a device has been successfully detected
    @Published var deviceDetected: Bool = false
    
    // True if the current selectedConfig was imported from a JSON file by the user.
    // False if it was auto-generated from the device partition table.
    @Published var hasUserJsonConfig: Bool = false
    
    // -------------------------------------------------------------------------
    // MARK: Published State — Port
    // -------------------------------------------------------------------------
    
    // List of available serial ports on the system
    @Published var availablePorts: [String] = []
    
    // Currently selected serial port
    @Published var selectedPort: String = ""
    
    // -------------------------------------------------------------------------
    // MARK: Published State — Operation
    // -------------------------------------------------------------------------
    
    // Current operation type
    @Published var currentOperation: OperationType = .none
    
    // Current operation state
    @Published var operationState: OperationState = .idle
    
    // Progress value 0.0 to 1.0 for the progress bar
    @Published var progress: Double = 0.0
    
    // Human-readable progress description (e.g. "Writing at 0x00043E30...")
    @Published var progressDescription: String = ""
    
    // Error message if the operation failed
    @Published var errorMessage: String = ""
    
    // -------------------------------------------------------------------------
    // MARK: Published State — Console
    // -------------------------------------------------------------------------
    
    // All console messages for the current session
    @Published var consoleMessages: [ConsoleMessage] = []
    
    // Full plain-text log for copying to clipboard
    @Published var consoleLog: String = ""
    
    // -------------------------------------------------------------------------
    // MARK: Published State — Flash Operation
    // -------------------------------------------------------------------------
    
    // The flash region selected for the current operation
    @Published var selectedRegion: FlashRegion?
    
    // The .bin file selected by the user for flashing
    @Published var selectedBinFileURL: URL?
    
    // The output file URL for read/backup operations
    @Published var outputFileURL: URL?
    
    // Whether the selected file is larger than the target region
    @Published var fileLargerThanRegion: Bool = false
    
    // -------------------------------------------------------------------------
    // MARK: Private Properties
    // -------------------------------------------------------------------------
    
    // The running esptool process (if any)
    private var process: Process?
    
    // Timer for periodic port scanning
    private var portScanTimer: Timer?
    
    // Path to the esptool binary in the app bundle
    private var esptoolPath: String {
        guard let path = Bundle.main.path(forResource: "esptool", ofType: nil) else {
            fatalError("esptool not found in app bundle. Check Copy Bundle Resources.")
        }
        return path
    }
    
    // -------------------------------------------------------------------------
    // MARK: Initialisation
    // -------------------------------------------------------------------------
    
    init() {
        // loadDeviceConfigs() // Disabled — using device partition table instead
        startPortScanning()
        operationState = .idle
    }
    
    // -------------------------------------------------------------------------
    // MARK: Device Config Loading
    // -------------------------------------------------------------------------
    
    // Loads all device config JSON files from the bundle's devices/ folder.
    // Called once on init.
    func loadDeviceConfigs() {
        availableConfigs = DeviceConfigLoader.loadAll()
        appendConsole("Loaded \(availableConfigs.count) device config(s).", type: .info)
        for config in availableConfigs {
            appendConsole("  • \(config.device.name) (\(config.device.id))", type: .dim)
        }
    }
    
    // Manually select a device config (user override).
    func selectConfig(_ config: DeviceConfig) {
        selectedConfig = config
        appendConsole("Device config set manually: \(config.device.name)", type: .info)
    }
    
    // -------------------------------------------------------------------------
    // MARK: Port Scanning
    // -------------------------------------------------------------------------
    
    // Starts a repeating timer that scans for available serial ports every 2 seconds.
    // This allows the app to detect when a device is connected or disconnected.
    func startPortScanning() {
        scanForPorts()
        portScanTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scanForPorts()
            }
        }
    }
    
    // Scans /dev/ for serial port devices matching common ESP32 USB chip patterns.
    // CP2104 (Micro-B): cu.usbserial-XXXX
    // CH340 (USB-C):    cu.wchusbserial-XXXX or cu.usbserial-XXXX
    func scanForPorts() {
        let fileManager = FileManager.default
        guard let devContents = try? fileManager.contentsOfDirectory(atPath: "/dev/") else {
            return
        }
        
        // Filter for serial ports matching ESP32 USB chip naming patterns.
        let ports = devContents
            .filter { name in
                name.hasPrefix("cu.usbserial") ||
                name.hasPrefix("cu.wchusbserial") ||
                name.hasPrefix("cu.SLAB_USBtoUART")
            }
            .map { "/dev/\($0)" }
            .sorted()
        
        // Only update if the list has changed to avoid unnecessary UI refreshes.
        if ports != availablePorts {
            availablePorts = ports
            
            // Auto-select the first port if none is selected.
            // Auto-select the first port if none is selected.
            if selectedPort.isEmpty, let first = ports.first {
                selectedPort = first
                appendConsole("Port auto-selected: \(first)", type: .info)
                // Auto-detect device when a port is first found.
                detectDevice()
            }
            
            // If the selected port disappeared, clear it.
            if !selectedPort.isEmpty && !ports.contains(selectedPort) {
                appendConsole("Port disconnected: \(selectedPort)", type: .warning)
                selectedPort = ports.first ?? ""
                deviceDetected = false
            }
        }
    }
    
    // -------------------------------------------------------------------------
    // MARK: Device Detection
    // -------------------------------------------------------------------------
    
    // Runs esptool chip_id to detect the connected device.
    // Parses the output to extract chip model, flash size, MAC, and revision.
    // Attempts to match the detected device to a loaded config file.
    func detectDevice() {
        guard !selectedPort.isEmpty else {
            appendConsole("No port selected. Connect a device and select a port.", type: .error)
            return
        }
        
        clearConsole()
        currentOperation = .detect
        operationState = .running
        deviceDetected = false
        appendConsole("Detecting device on \(selectedPort)...", type: .info)
        
        // esptool command: flash_id gives us chip info and flash size
        let args = [
            "--port", selectedPort,
            "flash-id"
        ]
        
        runEsptool(args: args) { [weak self] output, exitCode in
            guard let self = self else { return }
            
            if exitCode == 0 {
                self.parseChipInfo(from: output)
                self.operationState = .success
                // Read partition table from device
                self.readPartitionTable()
            } else {
                self.operationState = .failure
                self.errorMessage = "Device detection failed. Check the port and try again."
                self.appendConsole("Detection failed (exit code \(exitCode))", type: .error)
            }
            self.currentOperation = .none
        }
    }
    
    
    // -------------------------------------------------------------------------
    // MARK: Partition Table Detection
    // -------------------------------------------------------------------------
    
    // Reads the partition table from flash address 0x8000 and parses it.
    // Called automatically after successful device detection.
    // Updates selectedConfig regions with detected partition data merged
    // with any JSON config overlay.
    func readPartitionTable() {
        guard !selectedPort.isEmpty else { return }
        
        appendConsole("Reading partition table from 0x8000...", type: .info)
        
        // Read 4096 bytes (one sector) from 0x8000
        let tempFile = NSTemporaryDirectory() + "esp32_partition_table.bin"
        
        let args = [
            "--port", selectedPort,
            "read-flash",
            "0x8000",
            "0x1000",
            tempFile
        ]
        
        runEsptool(args: args) { [weak self] output, exitCode in
            guard let self = self else { return }
            
            guard exitCode == 0 else {
                self.appendConsole("Failed to read partition table.", type: .error)
                return
            }
            
            // Read the binary data
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: tempFile)) else {
                self.appendConsole("Could not read partition table file.", type: .error)
                return
            }
            
            // Parse the partition table
            let result = PartitionTableParser.parse(data: data)
            
            if result.isValid {
                self.appendConsole("Partition table parsed — \(result.partitions.count) partitions found.", type: .success)
                
                // Log each detected partition
                for partition in result.partitions {
                    self.appendConsole(
                        "  \(partition.label.padding(toLength: 12, withPad: " ", startingAt: 0)) \(String(format: "0x%08X", partition.offset))  \(partition.sizeFormatted)",
                        type: .dim
                    )
                }
                
                // Convert detected partitions directly to FlashRegions
                // JSON config overlay is disabled — using device data only
                let detectedRegions = result.partitions.map { $0.toFlashRegion() }
                
                // Build a minimal DeviceConfig from what we detected
                let deviceInfo = DeviceInfo(
                    id: "detected_\(self.detectedChipModel.lowercased().replacingOccurrences(of: "-", with: "_"))",
                    name: self.detectedChipModel,
                    description: "Auto-detected ESP32 device · \(self.detectedFlashSize / (1024*1024)) MB flash",
                    chipModel: self.detectedChipModel,
                    flashSize: self.detectedFlashSize
                )
                
                self.selectedConfig = DeviceConfig(
                    device: deviceInfo,
                    regions: detectedRegions
                )
                self.deviceDetected = true
                self.hasUserJsonConfig = false
                self.appendConsole("Regions updated from device partition table.", type: .success)
                
                // JSON config overlay — disabled for now
                // Uncomment to re-enable JSON config merging:
                // if let jsonConfig = DeviceConfigLoader.loadAll().first(where: {
                //     $0.device.chipModel == self.detectedChipModel &&
                //     $0.device.flashSize == self.detectedFlashSize
                // }) {
                //     let mergedRegions = DeviceConfigLoader.merge(
                //         detected: result.partitions,
                //         config: jsonConfig
                //     )
                //     self.selectedConfig = DeviceConfig(device: jsonConfig.device, regions: mergedRegions)
                // }
                
            } else {
                self.appendConsole("Partition table parse failed: \(result.error ?? "unknown error")", type: .error)
            }
            
            // Clean up temp file
            try? FileManager.default.removeItem(atPath: tempFile)
        }
    }
    
    // Parses esptool output to extract device information.
    // Updates detectedChipModel, detectedFlashSize, detectedMAC, detectedRevision.
    private func parseChipInfo(from output: String) {
        let lines = output.components(separatedBy: "\n")
        
        for line in lines {
            // Chip type line: "Chip type:          ESP32-D0WD-V3 (revision v3.1)"
            if line.contains("Chip type:") || line.contains("Chip is") {
                // Extract chip model
                if let match = line.range(of: "ESP32[^\\s(]+", options: .regularExpression) {
                    detectedChipModel = String(line[match])
                }
                // Extract revision
                if let revStart = line.range(of: "revision v"),
                   let revEnd = line.range(of: ")", range: revStart.upperBound..<line.endIndex) {
                    detectedRevision = "v" + String(line[revStart.upperBound..<revEnd.lowerBound])
                }
            }
            
            // MAC line: "MAC:                88:13:bf:58:61:34"
            if line.contains("MAC:") {
                let parts = line.components(separatedBy: "MAC:")
                if parts.count > 1 {
                    detectedMAC = parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
            
            // Flash size line: "Flash size:         16MB"
            if line.lowercased().contains("flash size") && line.contains("MB") {
                if let match = line.range(of: "\\d+MB", options: .regularExpression) {
                    let sizeStr = String(line[match]).replacingOccurrences(of: "MB", with: "")
                    if let sizeMB = Int(sizeStr) {
                        detectedFlashSize = sizeMB * 1024 * 1024
                    }
                }
            }
        }
        
        // Chip info parsed. Partition table will be read next by readPartitionTable().
        if !detectedChipModel.isEmpty {
            appendConsole("Chip: \(detectedChipModel), Flash: \(detectedFlashSize / (1024*1024)) MB", type: .dim)
        }
    }
    
    // -------------------------------------------------------------------------
    // MARK: Flash Operations — Write
    // -------------------------------------------------------------------------
    
    // Flashes a .bin file to a specific flash address.
    // address: the target flash address as a UInt32
    // fileURL: the .bin file to flash
    func flashBin(to address: UInt32, fileURL: URL) {
        guard !selectedPort.isEmpty else {
            appendConsole("No port selected.", type: .error)
            return
        }
        
        clearConsole()
        currentOperation = .flash
        operationState = .running
        progress = 0.0
        
        let addressHex = String(format: "0x%X", address)
        appendConsole("Flashing \(fileURL.lastPathComponent) to \(addressHex)...", type: .info)
        
        // esptool write-flash command with the address and file path.
        let args = [
            "--port", selectedPort,
            "write-flash",
            addressHex,
            fileURL.path
        ]
        
        runEsptool(args: args) { [weak self] output, exitCode in
            guard let self = self else { return }
            if exitCode == 0 {
                self.operationState = .success
                self.progress = 1.0
                self.appendConsole("Flash complete.", type: .success)
            } else {
                self.operationState = .failure
                self.errorMessage = "Flash operation failed. See console for details."
                self.appendConsole("Flash failed (exit code \(exitCode))", type: .error)
            }
            self.currentOperation = .none
        }
    }
    
    // Flashes multiple .bin files in a single esptool invocation.
    // files: array of (address, fileURL) pairs
    // This matches the Arduino "Export Compiled Binary" workflow where
    // bootloader, partition table, and firmware are separate files.
    func flashMultiple(files: [(address: UInt32, url: URL)]) {
        guard !selectedPort.isEmpty else {
            appendConsole("No port selected.", type: .error)
            return
        }
        
        clearConsole()
        currentOperation = .flash
        operationState = .running
        progress = 0.0
        
        appendConsole("Flashing \(files.count) file(s)...", type: .info)
        for file in files {
            appendConsole("  \(String(format: "0x%X", file.address)) → \(file.url.lastPathComponent)", type: .dim)
        }
        
        // Build the write-flash argument list with alternating address/file pairs.
        // e.g. write-flash 0x1000 bootloader.bin 0x8000 partitions.bin 0x10000 app.bin
        var args = ["--port", selectedPort, "write-flash"]
        for file in files {
            args.append(String(format: "0x%X", file.address))
            args.append(file.url.path)
        }
        
        runEsptool(args: args) { [weak self] output, exitCode in
            guard let self = self else { return }
            if exitCode == 0 {
                self.operationState = .success
                self.progress = 1.0
                self.appendConsole("Multi-file flash complete.", type: .success)
            } else {
                self.operationState = .failure
                self.errorMessage = "Flash operation failed. See console for details."
                self.appendConsole("Flash failed (exit code \(exitCode))", type: .error)
            }
            self.currentOperation = .none
        }
    }
    
    // -------------------------------------------------------------------------
    // MARK: Flash Operations — Read
    // -------------------------------------------------------------------------
    
    // Reads a flash region and saves it to a file.
    // address: start address of the region to read
    // size: number of bytes to read
    // outputURL: destination file for the read data
    func readFlash(from address: UInt32, size: Int, to outputURL: URL) {
        guard !selectedPort.isEmpty else {
            appendConsole("No port selected.", type: .error)
            return
        }
        
        clearConsole()
        currentOperation = .read
        operationState = .running
        progress = 0.0
        
        let addressHex = String(format: "0x%X", address)
        let sizeHex = String(format: "0x%X", size)
        appendConsole("Reading \(sizeHex) bytes from \(addressHex)...", type: .info)
        appendConsole("Output: \(outputURL.lastPathComponent)", type: .dim)
        
        let args = [
            "--port", selectedPort,
            "read-flash",
            addressHex,
            sizeHex,
            outputURL.path
        ]
        
        runEsptool(args: args) { [weak self] output, exitCode in
            guard let self = self else { return }
            if exitCode == 0 {
                self.operationState = .success
                self.progress = 1.0
                self.appendConsole("Read complete. Saved to \(outputURL.lastPathComponent)", type: .success)
            } else {
                self.operationState = .failure
                self.errorMessage = "Read operation failed. See console for details."
                self.appendConsole("Read failed (exit code \(exitCode))", type: .error)
            }
            self.currentOperation = .none
        }
    }
    
    // -------------------------------------------------------------------------
    // MARK: Flash Operations — Erase
    // -------------------------------------------------------------------------
    
    // Erases a flash region.
    // address: start address of the region to erase
    // size: number of bytes to erase (must be a multiple of 4096)
    func eraseRegion(at address: UInt32, size: Int) {
        guard !selectedPort.isEmpty else {
            appendConsole("No port selected.", type: .error)
            return
        }
        
        clearConsole()
        currentOperation = .erase
        operationState = .running
        progress = 0.0
        
        let addressHex = String(format: "0x%X", address)
        let sizeHex = String(format: "0x%X", size)
        appendConsole("Erasing \(sizeHex) bytes at \(addressHex)...", type: .warning)
        
        let args = [
            "--port", selectedPort,
            "erase-region",
            addressHex,
            sizeHex
        ]
        
        runEsptool(args: args) { [weak self] output, exitCode in
            guard let self = self else { return }
            if exitCode == 0 {
                self.operationState = .success
                self.progress = 1.0
                self.appendConsole("Erase complete.", type: .success)
            } else {
                self.operationState = .failure
                self.errorMessage = "Erase operation failed. See console for details."
                self.appendConsole("Erase failed (exit code \(exitCode))", type: .error)
            }
            self.currentOperation = .none
        }
    }
    
    // -------------------------------------------------------------------------
    // MARK: File Validation
    // -------------------------------------------------------------------------
    
    // Checks whether the selected .bin file fits within the target region.
    // Updates fileLargerThanRegion accordingly.
    func validateFileSize(fileURL: URL, region: FlashRegion) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let fileSize = attrs[.size] as? Int else {
            fileLargerThanRegion = false
            return
        }
        fileLargerThanRegion = fileSize > region.size
        if fileLargerThanRegion {
            appendConsole(
                "Warning: file is \(fileSize) bytes but region is only \(region.size) bytes.",
                type: .warning
            )
        }
    }
    
    // -------------------------------------------------------------------------
    // MARK: Cancel
    // -------------------------------------------------------------------------
    
    // Cancels the currently running esptool operation.
    func cancelOperation() {
        process?.terminate()
        process = nil
        operationState = .idle
        currentOperation = .none
        progress = 0.0
        appendConsole("Operation cancelled by user.", type: .warning)
    }
    
    // -------------------------------------------------------------------------
    // MARK: JSON Config Import/Export
    // -------------------------------------------------------------------------
    
    // Clears the current JSON config overlay.
    // The app falls back to the raw device partition table.
    func clearJsonConfig() {
        hasUserJsonConfig = false
        appendConsole("JSON config overlay cleared.", type: .info)
        // Re-build selectedConfig from detected partitions only
        // by re-running the partition table read
        if deviceDetected {
            readPartitionTable()
        }
    }
    
    // Imports a JSON device config from a file URL.
    // Merges it with the currently detected partition table.
    func importJsonConfig(from url: URL, completion: @escaping (Bool, String) -> Void) {
        do {
            let data = try Data(contentsOf: url)
            
            // Reject unedited template files
            if let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let isTemplate = raw["_template_marker"] as? Bool,
               isTemplate {
                DispatchQueue.main.async {
                    completion(false, "This is a template file. Edit it with your device details before importing.")
                }
                return
            }
            
            let config = try JSONDecoder().decode(DeviceConfig.self, from: data)
            DispatchQueue.main.async {
                // Always ensure Bootloader and Partition Table are present.
                // These exist at hardcoded addresses on all ESP32 devices and
                // are never listed in the partition table or JSON configs.
                let fixedRegions: [FlashRegion] = [
                    FlashRegion(
                        id: "bootloader",
                        name: "Bootloader",
                        address: "0x1000",
                        size: 28672,
                        operations: ["read"],
                        description: nil
                    ),
                    FlashRegion(
                        id: "partition_table",
                        name: "Partition Table",
                        address: "0x8000",
                        size: 4096,
                        operations: ["read"],
                        description: nil
                    )
                ]
                
                // Prepend fixed regions if not already defined in the JSON.
                let existingIDs = Set(config.regions.map { $0.id })
                let missingFixed = fixedRegions.filter { !existingIDs.contains($0.id) }
                let mergedRegions = missingFixed + config.regions
                
                let mergedConfig = DeviceConfig(
                    device: config.device,
                    regions: mergedRegions
                )
                
                self.selectedConfig = mergedConfig
                self.hasUserJsonConfig = true
                self.appendConsole("JSON config loaded: \(config.device.name)", type: .success)
                completion(true, "Config loaded: \(config.device.name)")
            }
        } catch {
            DispatchQueue.main.async {
                completion(false, "Could not load config: \(error.localizedDescription)")
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: esptool Subprocess
    // -------------------------------------------------------------------------

    // Launches esptool as a subprocess with the given arguments.
    // Streams stdout and stderr line by line to the console output.
    // Calls the completion handler on the main thread when done.
    private func runEsptool(
        args: [String],
        completion: @escaping (String, Int32) -> Void
    ) {
        // Log the full command for debugging.
        let fullCommand = ([esptoolPath] + args).joined(separator: " ")
        appendConsole("$ \(fullCommand)", type: .dim)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: esptoolPath)
        proc.arguments = args

        // Capture stdout and stderr on a single pipe.
        // esptool writes progress to stderr and results to stdout,
        // so we merge both to get the full output in order.
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        self.process = proc

        // Accumulate the full output for parsing after completion.
        let outputBox = OutputBox()

        // Read output line by line as it streams in.
        // This gives us real-time progress bar updates in the console.
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }

            outputBox.append(text)

            // Process each line individually for colour coding.
            let lines = text.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }

                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.processOutputLine(trimmed)
                }
            }
        }

        // Launch the process.
        do {
            try proc.run()
        } catch {
            appendConsole("Failed to launch esptool: \(error.localizedDescription)", type: .error)
            operationState = .failure
            errorMessage = error.localizedDescription
            completion("", -1)
            return
        }

        // Wait for completion on a background thread to avoid blocking the UI.
        Task.detached { [weak self] in
            proc.waitUntilExit()
            let exitCode = proc.terminationStatus

            // Small delay to allow final output to flush.
            try? await Task.sleep(nanoseconds: 100_000_000)

            await MainActor.run {
                self?.process = nil
                completion(outputBox.value, exitCode)
            }
        }
    }

    // Parses a single line of esptool output and appends it to the console
    // with the appropriate colour type.
    private func processOutputLine(_ line: String) {
        // Parse progress percentage from write progress lines.
        // e.g. "Writing at 0x00043e30 [=====>  ] 63.0%"
        if line.contains("Writing at") || line.contains("Reading from") {
            if let percentRange = line.range(of: #"\d+\.?\d*%"#, options: .regularExpression) {
                let percentStr = String(line[percentRange])
                    .replacingOccurrences(of: "%", with: "")
                if let percent = Double(percentStr) {
                    progress = percent / 100.0
                    progressDescription = line
                }
            }
            // Only log every 10% to keep the console readable
            if let percentRange = line.range(of: #"\d+\.?\d*%"#, options: .regularExpression) {
                let percentStr = String(line[percentRange])
                    .replacingOccurrences(of: "%", with: "")
                if let percent = Double(percentStr), Int(percent) % 10 == 0 {
                    appendConsole(line, type: .progress)
                }
            }
            return
        }

        // Colour code based on content.
        if line.contains("error") || line.contains("Error") || line.contains("Fatal") || line.contains("failed") {
            appendConsole(line, type: .error)
        } else if line.contains("Hash of data verified") || line.contains("Wrote") || line.contains("OK") || line.contains("done") {
            appendConsole(line, type: .success)
        } else if line.contains("Warning") || line.contains("erased") || line.contains("Erase") {
            appendConsole(line, type: .warning)
        } else if line.contains("MAC:") || line.contains("Crystal") || line.contains("Features") || line.contains("Chip type") || line.contains("revision") {
            appendConsole(line, type: .dim)
        } else if line.contains("Connecting") || line.contains("Connected") || line.contains("Uploading") || line.contains("Running") || line.contains("Configuring") || line.contains("Compressed") || line.contains("Changing baud") {
            appendConsole(line, type: .info)
        } else {
            appendConsole(line, type: .normal)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Console Helpers
    // -------------------------------------------------------------------------

    // Appends a message to the console output.
    func appendConsole(_ text: String, type: ConsoleMessage.MessageType) {
        let message = ConsoleMessage(text: text, type: type)
        consoleMessages.append(message)
        consoleLog += text + "\n"
    }

    // Clears the console output for a new operation.
    func clearConsole() {
        consoleMessages.removeAll()
        consoleLog = ""
        progress = 0.0
        progressDescription = ""
        errorMessage = ""
        operationState = .idle
    }

    // Copies the full console log to the system clipboard.
    func copyConsoleToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(consoleLog, forType: .string)
    }

    // Copies a string to the system clipboard.
    // Used for copying individual addresses and values.
    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}


// Thread-safe output accumulator for esptool subprocess output.
private class OutputBox {
    private var buffer = ""
    private let lock = NSLock()

    func append(_ text: String) {
        lock.lock()
        buffer += text
        lock.unlock()
    }

    var value: String {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
}
