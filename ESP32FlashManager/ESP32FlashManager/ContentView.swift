// =============================================================================
// ContentView.swift
// ESP32 Flash Manager
// =============================================================================
//
// PURPOSE
// -------
// The root view of the ESP32 Flash Manager app. Implements a three-column
// NavigationSplitView with:
//   - Sidebar: navigation sections and connected device status
//   - Detail: context-sensitive panel based on sidebar selection
//
// NAVIGATION STRUCTURE
// --------------------
// The sidebar has two sections:
//
//   DEVICE
//     • Overview        — all flash regions as cards
//     • Device info     — full chip details
//
//   OPERATIONS
//     • Flash region    — write a .bin file to a flash address
//     • Read / backup   — read a flash region to a file
//     • Erase region    — erase a flash region
//
//   CONFIG
//     • Device configs  — list and select device configs
//     • Settings        — app settings
//
// RELATIONSHIP TO OTHER FILES
// ---------------------------
// - FlashViewModel.swift provides all state and operations.
// - DeviceConfig.swift defines the data models rendered here.
//
// =============================================================================

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// =============================================================================
// MARK: - Navigation Destination
// =============================================================================
// Enum representing every possible sidebar selection.
// Used to drive the detail panel content.

enum NavDestination: Hashable {
    case overview
    case deviceInfo
    case flashRegion
    case readBackup
    case eraseRegion
    case restoreBackup
    case deviceConfigs
    case settings
}

// =============================================================================
// MARK: - ContentView
// =============================================================================

struct ContentView: View {

    @StateObject private var vm = FlashViewModel()
    @State private var selectedDestination: NavDestination? = .overview

    var body: some View {
        NavigationSplitView {
            SidebarView(
                vm: vm,
                selectedDestination: $selectedDestination
            )
        } detail: {
            DetailView(
                vm: vm,
                destination: $selectedDestination
            )
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 800, minHeight: 560)
    }
}

// =============================================================================
// MARK: - SidebarView
// =============================================================================

struct SidebarView: View {

    @ObservedObject var vm: FlashViewModel
    @Binding var selectedDestination: NavDestination?

    var body: some View {
        List(selection: $selectedDestination) {

            // --- DEVICE section ---
            Section("Device") {
                Label("Overview", systemImage: "cpu")
                    .tag(NavDestination.overview)
                Label("Device info", systemImage: "info.circle")
                    .tag(NavDestination.deviceInfo)
            }

            // --- OPERATIONS section ---
            Section("Operations") {
                Label("Flash region", systemImage: "arrow.up.circle")
                    .tag(NavDestination.flashRegion)
                Label("Read / backup", systemImage: "arrow.down.circle")
                    .tag(NavDestination.readBackup)
                Label("Erase region", systemImage: "trash")
                    .tag(NavDestination.eraseRegion)
                Label("Restore backup", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .tag(NavDestination.restoreBackup)
            }

            // --- CONFIG section ---
            Section("Config") {
                Label("Device configs", systemImage: "square.stack")
                    .tag(NavDestination.deviceConfigs)
                Label("Settings", systemImage: "gearshape")
                    .tag(NavDestination.settings)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            DeviceStatusPill(vm: vm)
                .padding(12)
        }
    }
}

// =============================================================================
// MARK: - DeviceStatusPill
// =============================================================================
// Shows the currently connected device and port at the bottom of the sidebar.

struct DeviceStatusPill: View {

    @ObservedObject var vm: FlashViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // Port picker
            if !vm.availablePorts.isEmpty {
                Picker("Port", selection: $vm.selectedPort) {
                    ForEach(vm.availablePorts, id: \.self) { port in
                        Text(port).tag(port)
                    }
                }
                .labelsHidden()
                .font(.system(size: 11, design: .monospaced))
            }

            // Device status
            HStack(spacing: 6) {
                Circle()
                    .fill(vm.deviceDetected ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)

                if vm.deviceDetected, let config = vm.selectedConfig {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(config.device.name)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(2)
                        Text(vm.detectedMAC)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No device detected")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Detect button
            Button {
                vm.detectDevice()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(vm.operationState == .running && vm.currentOperation == .detect
                         ? "Detecting..." : "Detect device")
                }
                .font(.system(size: 11))
                .frame(maxWidth: .infinity)
            }
            .disabled(vm.selectedPort.isEmpty ||
                     (vm.operationState == .running && vm.currentOperation == .detect))
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
}

// =============================================================================
// MARK: - DetailView
// =============================================================================
// Routes to the correct detail panel based on the sidebar selection.

struct DetailView: View {

    @ObservedObject var vm: FlashViewModel
    @Binding var destination: NavDestination?

    var body: some View {
        switch destination {
        case .overview:
            OverviewView(vm: vm, selectedDestination: $destination)
        case .deviceInfo:
            DeviceInfoView(vm: vm)
        case .flashRegion:
            FlashRegionView(vm: vm)
        case .readBackup:
            ReadBackupView(vm: vm)
        case .eraseRegion:
            EraseRegionView(vm: vm)
        case .deviceConfigs:
            DeviceConfigsView().environmentObject(vm)
        case .settings:
            SettingsView().environmentObject(vm)
        case .restoreBackup:
            RestoreBackupView(vm: vm)
        case .none:
            OverviewView(vm: vm, selectedDestination: $destination)
        }
    }
}

// =============================================================================
// MARK: - OverviewView
// =============================================================================
// Shows all flash regions as cards with quick-action buttons.

struct OverviewView: View {
    
    @ObservedObject var vm: FlashViewModel
    @Binding var selectedDestination: NavDestination?

    var body: some View {
        VStack(spacing: 0) {

            // Toolbar
            HStack {
                Text("Flash regions")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    vm.detectDevice()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(vm.selectedPort.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if let config = vm.selectedConfig {
                // Region cards
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(config.regions) { region in
                            RegionCard(vm: vm, region: region, selectedDestination: $selectedDestination)
                        }
                    }
                    .padding(20)
                }
            } else {
                // No device / config selected
                ContentUnavailableView(
                    "No device selected",
                    systemImage: "cpu",
                    description: Text("Connect a device and press Detect, or select a config manually.")
                )
            }

            Divider()

            // Status bar
            StatusBar(vm: vm)
        }
    }
}

// =============================================================================
// MARK: - RegionCard
// =============================================================================
// A card showing one flash region with its address, size, and action buttons.

struct RegionCard: View {
   
    @ObservedObject var vm: FlashViewModel
    let region: FlashRegion
    @Binding var selectedDestination: NavDestination?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(region.name)
                        .font(.system(size: 13, weight: .semibold))
                    // Address range — click to copy
                    Button {
                        vm.copyToClipboard(region.addressFormatted)
                    } label: {
                        Text("\(region.addressFormatted) — \(region.endAddressFormatted)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Click to copy address")
                }
                Spacer()
                // Permissions badge
                Text(region.permissionsBadge)
                    .font(.system(size: 10))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(region.canWrite ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.1))
                    .foregroundStyle(region.canWrite ? Color.blue : Color.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Meta row
            HStack(spacing: 20) {
                MetaItem(label: "Size", value: region.sizeFormatted)
                MetaItem(label: "Type", value: region.id)
                if let desc = region.description {
                    MetaItem(label: "Notes", value: desc)
                }
            }

            // Action buttons
            HStack(spacing: 8) {
                if region.canWrite {
                    ActionButton(label: "Flash", icon: "arrow.up.circle") {
                        vm.selectedRegion = region
                        selectedDestination = .flashRegion
                    }
                }
                if region.canRead {
                    ActionButton(label: "Read", icon: "arrow.down.circle") {
                        vm.selectedRegion = region
                        selectedDestination = .readBackup
                    }
                }
                if region.canErase {
                    ActionButton(label: "Erase", icon: "trash") {
                        vm.selectedRegion = region
                        selectedDestination = .eraseRegion
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
}

// =============================================================================
// MARK: - FlashRegionView
// =============================================================================
// Detail panel for flashing a .bin file to a region.

struct FlashRegionView: View {

    @ObservedObject var vm: FlashViewModel
    @State private var showConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            PanelToolbar(title: "Flash region")
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Region picker
                    RegionPicker(vm: vm)

                    // File picker
                    if vm.selectedRegion != nil {
                        FilePicker(
                            label: "Binary file to flash",
                            prompt: "Choose .bin file",
                            fileURL: $vm.selectedBinFileURL
                        ) { url in
                            if let region = vm.selectedRegion {
                                vm.validateFileSize(fileURL: url, region: region)
                            }
                        }
                    }

                    // File size warning
                    if vm.fileLargerThanRegion {
                        WarningBox(
                            message: "The selected file is larger than the target region. Flashing may corrupt adjacent regions."
                        )
                    }

                    // Standard warning
                    if vm.selectedRegion != nil && vm.selectedBinFileURL != nil && !vm.fileLargerThanRegion {
                        WarningBox(
                            message: "This will overwrite the contents of \(vm.selectedRegion?.name ?? "the selected region") at \(vm.selectedRegion?.addressFormatted ?? ""). This cannot be undone."
                        )
                    }

                    // Progress
                    if vm.currentOperation == .flash {
                        ProgressSection(vm: vm)
                    }

                    // Result
                    ResultBanner(vm: vm)

                    // Action buttons
                    HStack {
                        Spacer()
                        if vm.operationState == .running {
                            Button("Cancel") { vm.cancelOperation() }
                                .buttonStyle(.bordered)
                        } else {
                            Button("Flash now") {
                                showConfirm = true
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(vm.selectedRegion == nil ||
                                     vm.selectedBinFileURL == nil ||
                                     vm.fileLargerThanRegion ||
                                     vm.selectedPort.isEmpty)
                        }
                    }
                }
                .padding(20)
            }.onAppear {
                vm.operationState = .idle
            }

            Divider()
            ConsolePanel(vm: vm)
            Divider()
            StatusBar(vm: vm)
        }
        .confirmationDialog(
            "Flash \(vm.selectedRegion?.name ?? "region")?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Flash now", role: .destructive) {
                if let region = vm.selectedRegion,
                   let fileURL = vm.selectedBinFileURL {
                    vm.flashBin(to: region.addressValue, fileURL: fileURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will overwrite \(vm.selectedRegion?.name ?? "the region") at \(vm.selectedRegion?.addressFormatted ?? ""). Are you sure?")
        }
    }
}

// =============================================================================
// MARK: - ReadBackupView
// =============================================================================
// Detail panel for reading a flash region to a file.

struct ReadBackupView: View {

    @ObservedObject var vm: FlashViewModel
    @State private var showSavePanel = false

    var body: some View {
        VStack(spacing: 0) {
            PanelToolbar(title: "Read / backup")
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    RegionPicker(vm: vm)

                    // Output file
                    if vm.selectedRegion != nil {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Output file")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            HStack {
                                Text(vm.outputFileURL?.lastPathComponent ?? "No file selected")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(vm.outputFileURL == nil ? .secondary : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                                    )
                                Button("Choose") {
                                    let panel = NSSavePanel()
                                    panel.allowedContentTypes = [UTType.data]
                                    
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "yyyyMMdd_HHmm"
                                    let timestamp = formatter.string(from: Date())
                                    panel.nameFieldStringValue = "\(vm.selectedRegion?.id ?? "backup")_\(timestamp).bin"
                                    
                                    if panel.runModal() == .OK {
                                        vm.outputFileURL = panel.url
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    // Progress
                    if vm.currentOperation == .read {
                        ProgressSection(vm: vm)
                    }

                    ResultBanner(vm: vm)

                    HStack {
                        Spacer()
                        if vm.operationState == .running {
                            Button("Cancel") { vm.cancelOperation() }
                                .buttonStyle(.bordered)
                        } else {
                            Button("Read region") {
                                if let region = vm.selectedRegion,
                                   let outputURL = vm.outputFileURL {
                                    vm.readFlash(
                                        from: region.addressValue,
                                        size: region.size,
                                        to: outputURL
                                    )
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(vm.selectedRegion == nil ||
                                     vm.outputFileURL == nil ||
                                     vm.selectedPort.isEmpty)
                        }
                    }
                }
                .padding(20)
            }.onAppear {
                vm.operationState = .idle
            }

            Divider()
            ConsolePanel(vm: vm)
            Divider()
            StatusBar(vm: vm)
        }
    }
}

// =============================================================================
// MARK: - EraseRegionView
// =============================================================================
// Detail panel for erasing a flash region.

struct EraseRegionView: View {

    @ObservedObject var vm: FlashViewModel
    @State private var showConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            PanelToolbar(title: "Erase region")
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    RegionPicker(vm: vm)

                    if vm.selectedRegion != nil {
                        WarningBox(
                            message: "Erasing \(vm.selectedRegion?.name ?? "this region") (\(vm.selectedRegion?.sizeFormatted ?? "")) at \(vm.selectedRegion?.addressFormatted ?? "") will fill it with 0xFF bytes. This cannot be undone."
                        )
                    }

                    if vm.currentOperation == .erase {
                        ProgressSection(vm: vm)
                    }

                    ResultBanner(vm: vm)

                    HStack {
                        Spacer()
                        if vm.operationState == .running {
                            Button("Cancel") { vm.cancelOperation() }
                                .buttonStyle(.bordered)
                        } else {
                            Button("Erase region") {
                                showConfirm = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .disabled(vm.selectedRegion == nil || vm.selectedPort.isEmpty)
                        }
                    }
                }
                .padding(20)
            }.onAppear {
                vm.operationState = .idle
            }

            Divider()
            ConsolePanel(vm: vm)
            Divider()
            StatusBar(vm: vm)
        }
        .confirmationDialog(
            "Erase \(vm.selectedRegion?.name ?? "region")?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Erase", role: .destructive) {
                if let region = vm.selectedRegion {
                    vm.eraseRegion(at: region.addressValue, size: region.size)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will erase \(vm.selectedRegion?.sizeFormatted ?? "") at \(vm.selectedRegion?.addressFormatted ?? ""). All data will be lost.")
        }
    }
}


// =============================================================================
// MARK: - RestoreBackupView
// =============================================================================
// Detail panel for restoring a previously backed-up .bin file to the board.

// =============================================================================
// MARK: - RestoreBackupView
// =============================================================================
// Full board restore from a single merged .bin file.
// The merged file contains the entire flash contents (16 MB) with all regions
// placed at their correct offsets. It is written to address 0x0.
//
// VALIDATION
// ----------
// The app checks that the file is a valid ESP32 flash image by verifying
// the firmware magic byte 0xE9 is present at offset 0x10000 (app0 address).

struct RestoreBackupView: View {

    @ObservedObject var vm: FlashViewModel
    @State private var showConfirm = false
    @State private var restoreFileURL: URL? = nil
    @State private var restoreFileSize: Int = 0
    @State private var isValidImage: Bool = false
    @State private var validationMessage: String = ""

    var body: some View {
        VStack(spacing: 0) {
            PanelToolbar(title: "Restore backup")
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Info box
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Full board restore")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Restores a complete 16 MB merged flash image to the board starting at address 0x00000000. This overwrites all regions including bootloader, partition table, firmware, and data.")
                                .font(.system(size: 12))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // File picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Merged flash image (.bin)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(restoreFileURL?.lastPathComponent ?? "No file selected")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(restoreFileURL == nil ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                                )
                            Button("Choose") {
                                let panel = NSOpenPanel()
                                panel.allowedContentTypes = [UTType.data]
                                panel.allowsMultipleSelection = false
                                panel.canChooseDirectories = false
                                if panel.runModal() == .OK, let url = panel.url {
                                    restoreFileURL = url
                                    validateRestoreFile(url: url)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    // File info and validation
                    if let fileURL = restoreFileURL {
                        HStack(spacing: 20) {
                            MetaItem(label: "File", value: fileURL.lastPathComponent)
                            MetaItem(label: "Size", value: formatBytes(restoreFileSize))
                        }

                        // Validation result
                        if isValidImage {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(validationMessage)
                                    .font(.system(size: 12))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text(validationMessage)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // Warning
                        if isValidImage {
                            WarningBox(
                                message: "This will overwrite the ENTIRE flash memory of the connected device starting at 0x00000000. All existing firmware, settings, and data will be replaced. This cannot be undone. Do not disconnect the device during restore."
                            )
                        }
                    }

                    // Progress
                    if vm.currentOperation == .flash {
                        ProgressSection(vm: vm)
                    }

                    ResultBanner(vm: vm)

                    // Action buttons
                    HStack {
                        Spacer()
                        if vm.operationState == .running {
                            Button("Cancel") { vm.cancelOperation() }
                                .buttonStyle(.bordered)
                        } else {
                            Button("Restore entire board") {
                                showConfirm = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .disabled(restoreFileURL == nil ||
                                     !isValidImage ||
                                     vm.selectedPort.isEmpty)
                        }
                    }
                }
                .padding(20)
            }
            .onAppear {
                vm.operationState = .idle
            }

            Divider()
            ConsolePanel(vm: vm)
            Divider()
            StatusBar(vm: vm)
        }
        .confirmationDialog(
            "Restore entire board?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Restore entire board", role: .destructive) {
                if let fileURL = restoreFileURL {
                    // Flash to address 0x0 — the start of flash
                    vm.flashBin(to: 0x0, fileURL: fileURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will overwrite the entire flash memory with \(restoreFileURL?.lastPathComponent ?? "the backup file"). Are you sure?")
        }
    }

    // Validates the selected file is a plausible ESP32 merged flash image.
    // Checks:
    //   1. File is at least 64 KB (too small = not a real image)
    //   2. Magic byte 0xE9 is present at offset 0x10000 (app0 firmware start)
    func validateRestoreFile(url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            isValidImage = false
            validationMessage = "Could not read file."
            return
        }

        restoreFileSize = data.count

        // Must be at least 64 KB
        guard data.count >= 0x10000 + 4 else {
            isValidImage = false
            validationMessage = "File too small to be a valid flash image (\(formatBytes(data.count)))."
            return
        }

        // Check for ESP32 firmware magic byte at app0 offset
        let magicByte = data[0x10000]
        guard magicByte == 0xE9 else {
            isValidImage = false
            validationMessage = "Invalid image — expected firmware magic byte 0xE9 at 0x10000, found 0x\(String(format: "%02X", magicByte))."
            return
        }

        isValidImage = true
        validationMessage = "Valid ESP32 flash image — firmware magic 0xE9 confirmed at 0x10000."
    }

    func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1_048_576 {
            let mb = bytes / 1_048_576
            return "\(mb) MB (\(bytes / 1024) KB)"
        } else if bytes >= 1024 {
            return "\(bytes / 1024) KB"
        }
        return "\(bytes) bytes"
    }
}

// =============================================================================
// MARK: - DeviceInfoView
// =============================================================================
// Shows full chip details for the connected device.

struct DeviceInfoView: View {

    @ObservedObject var vm: FlashViewModel

    var body: some View {
        VStack(spacing: 0) {
            PanelToolbar(title: "Device info")
            Divider()

            if vm.deviceDetected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Chip details card
                        InfoCard(title: "Chip") {
                            InfoRow(label: "Model", value: vm.detectedChipModel)
                            InfoRow(label: "Revision", value: vm.detectedRevision)
                            InfoRow(label: "MAC address", value: vm.detectedMAC)
                            InfoRow(label: "Flash size",
                                   value: "\(vm.detectedFlashSize / (1024*1024)) MB (\(vm.detectedFlashSize) bytes)")
                        }

                        // Config details card
                        if let config = vm.selectedConfig {
                            InfoCard(title: "Device config") {
                                InfoRow(label: "Config ID", value: config.device.id)
                                InfoRow(label: "Name", value: config.device.name)
                                InfoRow(label: "Description",
                                       value: config.device.description ?? "—")
                                InfoRow(label: "Regions",
                                       value: "\(config.regions.count) defined")
                            }
                        }

                        // Port details card
                        InfoCard(title: "Connection") {
                            InfoRow(label: "Port", value: vm.selectedPort)
                        }
                    }
                    .padding(20)
                }
            } else {
                ContentUnavailableView(
                    "No device detected",
                    systemImage: "cpu",
                    description: Text("Press Detect device in the sidebar to identify the connected hardware.")
                )
            }

            Divider()
            StatusBar(vm: vm)
        }
    }
}

// =============================================================================
// MARK: - DeviceConfigsView
// =============================================================================
// Manages the device JSON config — import, export template, and clear.
//
// FUTURE: Bundle config list (vm.availableConfigs) is scaffolded but disabled.
// To re-enable: uncomment loadDeviceConfigs() in FlashViewModel.init() and
// uncomment the BundleConfigsSection below. This allows shipping pre-built
// configs for common boards inside the app bundle.

struct DeviceConfigsView: View {

    @EnvironmentObject var vm: FlashViewModel
    @State private var showImportPanel = false
    @State private var showExportPanel = false
    @State private var feedbackMessage: String = ""
    @State private var feedbackIsError: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            PanelToolbar(title: "Device configs")
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ---- Current config status ----
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ACTIVE CONFIG")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("By default, the app reads the partition table directly from your device and displays all detected regions automatically.\n\nA JSON config is optional. When loaded, it replaces the detected regions with a user-defined layout giving you control over which regions are shown, their names, descriptions, and permitted operations.\n\nTo create a config for your device, export the template, edit it with your device details, and import it here.")                  .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            Divider()

                            HStack(spacing: 8) {
                                Image(systemName: vm.hasUserJsonConfig
                                      ? "checkmark.circle.fill" : "circle.dashed")
                                    .foregroundStyle(vm.hasUserJsonConfig ? .green : .secondary)
                                    .font(.system(size: 13))
                                Text(vm.hasUserJsonConfig
                                     ? "JSON config loaded: \(vm.selectedConfig?.device.name ?? "")"
                                     : "No JSON config — using device partition table")
                                    .font(.system(size: 12))
                            }

                            HStack(spacing: 8) {
                                Button {
                                    showImportPanel = true
                                } label: {
                                    Label("Import config…", systemImage: "arrow.up.doc")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    showExportPanel = true
                                } label: {
                                    Label("Export template…", systemImage: "arrow.down.doc")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.bordered)

                                if vm.hasUserJsonConfig {
                                    Button(role: .destructive) {
                                        vm.clearJsonConfig()
                                        feedbackIsError = false
                                        feedbackMessage = "Config cleared. Partition table reloaded from device."
                                    } label: {
                                        Label("Clear config", systemImage: "trash")
                                            .font(.system(size: 12))
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            if !feedbackMessage.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: feedbackIsError
                                          ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                        .foregroundStyle(feedbackIsError ? .red : .green)
                                        .font(.system(size: 12))
                                    Text(feedbackMessage)
                                        .font(.system(size: 12))
                                        .foregroundStyle(feedbackIsError ? .red : .primary)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                    }

                    // ---- Bundle configs (disabled) ----
                    // FUTURE: uncomment this section and loadDeviceConfigs() in
                    // FlashViewModel.init() to enable bundled device config support.
                    //
                    // BundleConfigsSection(vm: vm)

                    Spacer()
                }
                .padding(20)
            }

            Divider()
            StatusBar(vm: vm)
        }
        .fileImporter(
            isPresented: $showImportPanel,
            allowedContentTypes: [.json]
        ) { result in
            feedbackMessage = ""
            switch result {
            case .success(let url):
                vm.importJsonConfig(from: url) { success, message in
                    feedbackIsError = !success
                    feedbackMessage = message
                }
            case .failure(let err):
                feedbackIsError = true
                feedbackMessage = err.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $showExportPanel,
            document: ConfigTemplateDocument(),
            contentType: .json,
            defaultFilename: "esp32_config_template"
        ) { result in
            switch result {
            case .success:
                feedbackIsError = false
                feedbackMessage = "Template exported successfully."
            case .failure(let err):
                feedbackIsError = true
                feedbackMessage = err.localizedDescription
            }
        }
    }
}

// FUTURE: Bundle config list — disabled until loadDeviceConfigs() is re-enabled.
// Uncomment and add to DeviceConfigsView body to restore.
//
// struct BundleConfigsSection: View {
//     @ObservedObject var vm: FlashViewModel
//     var body: some View {
//         VStack(alignment: .leading, spacing: 12) {
//             Text("BUNDLED CONFIGS")
//                 .font(.system(size: 11, weight: .semibold))
//                 .foregroundStyle(.secondary)
//                 .tracking(0.5)
//             if vm.availableConfigs.isEmpty {
//                 Text("No bundled configs found.")
//                     .font(.system(size: 12))
//                     .foregroundStyle(.secondary)
//             } else {
//                 ForEach(vm.availableConfigs) { config in
//                     HStack {
//                         VStack(alignment: .leading, spacing: 2) {
//                             Text(config.device.name)
//                                 .font(.system(size: 13, weight: .medium))
//                             Text("\(config.device.chipModel) · \(config.device.flashSize / (1024*1024)) MB flash · \(config.regions.count) regions")
//                                 .font(.system(size: 11))
//                                 .foregroundStyle(.secondary)
//                         }
//                         Spacer()
//                         if vm.selectedConfig?.id == config.id {
//                             Image(systemName: "checkmark.circle.fill")
//                                 .foregroundStyle(.green)
//                         }
//                     }
//                     .padding(.vertical, 4)
//                     .contentShape(Rectangle())
//                     .onTapGesture { vm.selectConfig(config) }
//                 }
//             }
//         }
//     }
// }


// =============================================================================
// MARK: - SettingsView
// =============================================================================

struct SettingsView: View {

    @EnvironmentObject var vm: FlashViewModel
    @State private var showImportPanel = false
    @State private var showExportPanel = false
    @State private var feedbackMessage: String = ""
    @State private var feedbackIsError: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            PanelToolbar(title: "Settings")
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ---- About section ----
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ABOUT")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("ESP32 Flash Manager")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text("v0.1")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Text("Open source macOS utility for reading, writing, and managing ESP32 flash memory.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                    }

                    Spacer()
                }
                .padding(20)
            }

            Divider()
            StatusBar(vm: vm)
        }
        // Import JSON config
        .fileImporter(
            isPresented: $showImportPanel,
            allowedContentTypes: [.json]
        ) { result in
            feedbackMessage = ""
            switch result {
            case .success(let url):
                vm.importJsonConfig(from: url) { success, message in
                    feedbackIsError = !success
                    feedbackMessage = message
                }
            case .failure(let err):
                feedbackIsError = true
                feedbackMessage = err.localizedDescription
            }
        }
        // Export config template
        .fileExporter(
            isPresented: $showExportPanel,
            document: ConfigTemplateDocument(),
            contentType: .json,
            defaultFilename: "esp32_config_template"
        ) { result in
            switch result {
            case .success:
                feedbackIsError = false
                feedbackMessage = "Template exported successfully."
            case .failure(let err):
                feedbackIsError = true
                feedbackMessage = err.localizedDescription
            }
        }
    }
}

// Document type for exporting the JSON config template via fileExporter.
// Loads the template from config_template.json in the app bundle.
struct ConfigTemplateDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    init() {}
    init(configuration: ReadConfiguration) throws {}
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url = Bundle.main.url(forResource: "config_template", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            // Fallback — should never happen if the file is in the bundle
            let fallback = "{ \"error\": \"config_template.json not found in app bundle\" }"
            return FileWrapper(regularFileWithContents: fallback.data(using: .utf8)!)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

// =============================================================================
// MARK: - ConsolePanel
// =============================================================================
// Scrolling console output panel with colour-coded lines and copy button.

struct ConsolePanel: View {

    @ObservedObject var vm: FlashViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Console header
            HStack {
                Label("Console output", systemImage: "terminal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    vm.copyConsoleToClipboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(vm.consoleMessages.isEmpty)

                Button {
                    vm.clearConsole()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(vm.consoleMessages.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Console output — dark background, monospaced, auto-scrolls
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(vm.consoleMessages) { message in
                            Text(message.text)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(consoleColor(for: message.type))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color(NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)))
                .frame(height: 180)
                .onChange(of: vm.consoleMessages.count) { _ in
                    // Auto-scroll to the latest message.
                    if let last = vm.consoleMessages.last {
                        withAnimation(.none) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // Maps console message types to display colours.
    func consoleColor(for type: ConsoleMessage.MessageType) -> Color {
        switch type {
        case .success:  return Color(red: 0.12, green: 0.62, blue: 0.46)  // green
        case .error:    return Color(red: 0.88, green: 0.29, blue: 0.29)  // red
        case .warning:  return Color(red: 0.94, green: 0.62, blue: 0.15)  // amber
        case .info:     return Color(red: 0.22, green: 0.54, blue: 0.87)  // blue
        case .progress: return Color(red: 0.37, green: 0.82, blue: 0.65)  // teal
        case .dim:    return Color(white: 0.45)   // grey
        case .normal: return Color(white: 0.75)   // light grey
        }
    }
}

// =============================================================================
// MARK: - StatusBar
// =============================================================================
// Bottom status bar showing device info and operation state.

struct StatusBar: View {

    @ObservedObject var vm: FlashViewModel

    var body: some View {
        HStack(spacing: 8) {
            // Operation indicator
            if vm.operationState == .running {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
                Text(operationLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else if vm.operationState == .success {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 11))
                Text("Ready")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else if vm.operationState == .failure {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 11))
                Text(vm.errorMessage)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.red)
            } else {
                Image(systemName: "circle.fill")
                    .foregroundStyle(vm.deviceDetected ? .green : .secondary.opacity(0.4))
                    .font(.system(size: 8))
                Text(statusText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer()

            // Port
            if !vm.selectedPort.isEmpty {
                Text(vm.selectedPort)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    var statusText: String {
        if vm.deviceDetected {
            let chip = vm.detectedChipModel.isEmpty ? "ESP32" : vm.detectedChipModel
            let rev  = vm.detectedRevision.isEmpty ? "" : " \(vm.detectedRevision)"
            let mb   = vm.detectedFlashSize > 0 ? " · \(vm.detectedFlashSize / (1024*1024)) MB flash" : ""
            let mac  = vm.detectedMAC.isEmpty ? "" : " · \(vm.detectedMAC)"
            return "\(chip)\(rev)\(mb)\(mac)"
        }
        return "No device connected"
    }

    var operationLabel: String {
        switch vm.currentOperation {
        case .flash:  return "Flashing — do not disconnect..."
        case .read:   return "Reading flash..."
        case .erase:  return "Erasing — do not disconnect..."
        case .detect: return "Detecting device..."
        case .none:   return ""
        }
    }
}

// =============================================================================
// MARK: - Reusable Sub-components
// =============================================================================

// Toolbar at the top of each detail panel.
struct PanelToolbar: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// Region picker — shown at the top of Flash, Read, and Erase panels.
struct RegionPicker: View {
    @ObservedObject var vm: FlashViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Target region")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            if let config = vm.selectedConfig {
                Picker("Region", selection: $vm.selectedRegion) {
                    Text("Select a region").tag(FlashRegion?.none)
                    ForEach(config.regions) { region in
                        Text("\(region.name)  \(region.addressFormatted)")
                            .tag(Optional(region))
                    }
                }
                .labelsHidden()
            } else {
                Text("No device config loaded. Detect a device or select a config.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// File picker for selecting a .bin file.
struct FilePicker: View {
    let label: String
    let prompt: String
    @Binding var fileURL: URL?
    var onSelect: ((URL) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            HStack {
                Text(fileURL?.lastPathComponent ?? "No file selected")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(fileURL == nil ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
                Button("Choose") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [UTType.data]
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK, let url = panel.url {
                        fileURL = url
                        onSelect?(url)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// Warning box shown before destructive operations.
struct WarningBox: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 14))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Color(NSColor.labelColor))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// Progress bar and description shown during operations.
struct ProgressSection: View {
    @ObservedObject var vm: FlashViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(vm.progressDescription.isEmpty ? "Working..." : vm.progressDescription)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text("\(Int(vm.progress * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.blue)
            }
            ProgressView(value: vm.progress)
                .progressViewStyle(.linear)
                .tint(.blue)
        }
    }
}

// Result banner shown after an operation completes.
struct ResultBanner: View {
    @ObservedObject var vm: FlashViewModel
    var body: some View {
        if vm.operationState == .success {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Operation completed successfully.")
                    .font(.system(size: 12))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if vm.operationState == .failure {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(vm.errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// A small label+value pair used in info cards.
struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .textSelection(.enabled)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// A card grouping a set of InfoRows with a title.
struct InfoCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
    }
}

// A small label+value meta item used in region cards.
struct MetaItem: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12))
                .lineLimit(1)
        }
    }
}

// A small action button used in region cards.
struct ActionButton: View {
    let label: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button {
            action()
        } label: {
            Label(label, systemImage: icon)
                .font(.system(size: 12))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

// =============================================================================
// MARK: - Preview
// =============================================================================

#Preview {
    ContentView()
}
