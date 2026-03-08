//
//  MacSettingsView.swift
//  FX-Live-Mac
//
//  Single-screen settings dashboard with grouped panels
//

import SwiftUI

struct MacSettingsView: View {
    @State private var logLevels = settings.logLevels
    @State private var countDownWarning = settings.countDownWarning
    @State private var resetToStart = settings.resetToStart
    @State private var performanceMode = settings.performanceMode
    @State private var promptForCueName = settings.promptForCueName
    @State private var autoAddEffect = settings.autoAddEffect
    @State private var remoteTrigger = settings.remoteTrigger
    @StateObject private var outputManager = MacOutputManager.shared
    
    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                // Left Column – Show & Design
                VStack(spacing: 16) {
                    showSettingsPanel
                    designSettingsPanel
                }
                .frame(maxWidth: .infinity)
                
                // Centre Column – Audio & Outputs
                VStack(spacing: 16) {
                    audioSettingsPanel
                    outputRoutingPanel
                }
                .frame(maxWidth: .infinity)
                
                // Right Column – About
                VStack(spacing: 16) {
                    aboutPanel
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            outputManager.enumerateDevices()
        }
    }
    
    // MARK: - Show Settings Panel
    
    private var showSettingsPanel: some View {
        MacSettingsPanel(title: "Show Settings", icon: "theatermasks.fill") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Performance Mode", isOn: $performanceMode)
                    .toggleStyle(.switch)
                    .onChange(of: performanceMode) { _, newValue in
                        settings.performanceMode = newValue
                        settings.save()
                    }
                
                Text("Protects levels and routing during a live show")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                
                Toggle("Remote Trigger", isOn: $remoteTrigger)
                    .toggleStyle(.switch)
                    .onChange(of: remoteTrigger) { _, newValue in
                        settings.remoteTrigger = newValue
                        settings.save()
                    }
                
                Toggle("Loop back to start after last cue", isOn: $resetToStart)
                    .toggleStyle(.switch)
                    .onChange(of: resetToStart) { _, newValue in
                        settings.resetToStart = newValue
                        settings.save()
                    }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Countdown Warning")
                        Spacer()
                        Text("\(countDownWarning)s")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: Binding(
                        get: { Double(countDownWarning) },
                        set: { countDownWarning = Int($0) }
                    ), in: 5...60, step: 1)
                    .onChange(of: countDownWarning) { _, newValue in
                        settings.countDownWarning = newValue
                        settings.save()
                    }
                }
            }
        }
    }
    
    // MARK: - Design Settings Panel
    
    private var designSettingsPanel: some View {
        MacSettingsPanel(title: "Design Settings", icon: "paintbrush.fill") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Prompt for cue name when adding", isOn: $promptForCueName)
                    .toggleStyle(.switch)
                    .onChange(of: promptForCueName) { _, newValue in
                        settings.promptForCueName = newValue
                        settings.save()
                    }
                
                Toggle("Auto-add effect when creating cue", isOn: $autoAddEffect)
                    .toggleStyle(.switch)
                    .onChange(of: autoAddEffect) { _, newValue in
                        settings.autoAddEffect = newValue
                        settings.save()
                    }
            }
        }
    }
    
    // MARK: - Audio Settings Panel
    
    private var audioSettingsPanel: some View {
        MacSettingsPanel(title: "Audio Settings", icon: "speaker.wave.2.fill") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Logarithmic volume curve", isOn: $logLevels)
                    .toggleStyle(.switch)
                    .onChange(of: logLevels) { _, newValue in
                        settings.logLevels = newValue
                        fx.audio.logLevels = newValue
                        fx.audio.globalVolume(10000)
                        settings.save()
                    }
                
                Text("Uses a logarithmic curve for more natural-feeling volume control")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Output Routing Panel
    
    private var outputRoutingPanel: some View {
        MacSettingsPanel(title: "Output Routing", icon: "arrow.triangle.branch") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Enable Multi-Output Routing", isOn: Binding(
                    get: { outputManager.multiOutputEnabled },
                    set: { outputManager.setMultiOutputEnabled($0) }
                ))
                .toggleStyle(.switch)
                
                Text("Route effects to separate audio devices or channel pairs on multi-channel interfaces.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if outputManager.multiOutputEnabled {
                    Divider()
                    
                    // Output bus list
                    ForEach(outputManager.buses) { bus in
                        MacOutputBusRow(
                            outputManager: outputManager,
                            busIndex: bus.id
                        )
                    }
                    
                    Divider()
                    
                    // Bus management controls
                    HStack(spacing: 8) {
                        Button {
                            outputManager.addBus()
                        } label: {
                            Label("Add Bus", systemImage: "plus.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button {
                            outputManager.removeLastBus()
                        } label: {
                            Label("Remove Last", systemImage: "minus.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(outputManager.buses.count <= MacOutputManager.minimumBusCount)
                        
                        Spacer()
                        
                        Button("Refresh Devices") {
                            outputManager.enumerateDevices()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    HStack {
                        Text("\(outputManager.buses.count) output bus(es)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(outputManager.availableDevices.count) device(s) found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - About Panel
    
    private var aboutPanel: some View {
        MacSettingsPanel(title: "About", icon: "info.circle.fill") {
            VStack(alignment: .leading, spacing: 14) {
                // App identity
                HStack(spacing: 12) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FX-Live Pro")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Professional Sound Effects Production")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // Version info
                HStack {
                    Text("Version")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
                
                Divider()
                
                // Links
                Button {
                    if let url = URL(string: "http://www.driftwoodsoftware.com") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("Driftwood Software")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Button {
                    if let url = URL(string: "https://www.facebook.com/fxlive.users") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("Facebook Community")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Button {
                    if let url = URL(string: "http://www.matt-fletcher.com") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("Music by Matt Fletcher")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Divider()
                
                Text("© 2012-2026 Driftwood Software")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    // MARK: - Helpers
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "1.0"
    }
}

// MARK: - Reusable Mac Settings Panel

/// A grouped panel with a title header, styled for macOS
struct MacSettingsPanel<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Content
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

// MARK: - Output Bus Row

struct MacOutputBusRow: View {
    @ObservedObject var outputManager: MacOutputManager
    let busIndex: Int
    
    /// Safely resolve the bus by id — returns nil if the bus has been removed
    private var bus: OutputBus? {
        outputManager.buses.first(where: { $0.id == busIndex })
    }
    
    /// The currently selected device (if any)
    private var selectedDevice: BASSOutputDevice? {
        guard let bus = bus else { return nil }
        return outputManager.availableDevices.first(where: { $0.id == bus.bassDeviceIndex })
    }
    
    var body: some View {
        if let bus = bus {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    // Bus label
                    Text("Output \(OutputBus.labelFor(busIndex))")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 80, alignment: .leading)
                    
                    // Device picker
                    Picker("", selection: Binding(
                        get: { bus.bassDeviceIndex },
                        set: { outputManager.assignDevice(busIndex: busIndex, deviceIndex: $0) }
                    )) {
                        Text("Default Output").tag(-1)
                        ForEach(outputManager.availableDevices) { device in
                            Text(device.displayName).tag(device.id)
                        }
                    }
                    .frame(minWidth: 180)
                    
                    // Channel pair picker (only shown for multi-channel devices)
                    if let device = selectedDevice, device.channelPairs > 1 {
                        Picker("", selection: Binding(
                            get: { bus.channelPair },
                            set: { outputManager.assignChannelPair(busIndex: busIndex, channelPair: $0) }
                        )) {
                            ForEach(0..<device.channelPairs, id: \.self) { pair in
                                Text(BASSOutputDevice.channelPairLabel(pair)).tag(pair)
                            }
                        }
                        .frame(minWidth: 120)
                    }
                    
                    // Status indicator
                    Circle()
                        .fill(bus.isInitialised ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .help(bus.isInitialised ? "Active" : "Not configured")
                    
                    // Test button
                    Button("Test") {
                        outputManager.testBus(busIndex)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!bus.isInitialised && bus.bassDeviceIndex < 0)
                }
                
                // Show channel info for multi-channel devices
                if let device = selectedDevice, device.channelPairs > 1 {
                    Text("\(device.name): \(device.channelCount) channels available (\(device.channelPairs) stereo pairs)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 80)
                }
            }
        }
    }
}
