//
//  MacSettingsView.swift
//  FX-Live-Mac
//
//  Full macOS Settings view
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
        TabView {
            // Audio Settings
            Form {
                Section("Volume") {
                    Toggle("Logarithmic volume curve", isOn: $logLevels)
                        .onChange(of: logLevels) { _, newValue in
                            settings.logLevels = newValue
                            fx.audio.logLevels = newValue
                            fx.audio.globalVolume(10000)
                            settings.save()
                        }
                }
                
                Section("Playback") {
                    Toggle("Reset to start after last cue", isOn: $resetToStart)
                        .onChange(of: resetToStart) { _, newValue in
                            settings.resetToStart = newValue
                            settings.save()
                        }
                    
                    HStack {
                        Text("Countdown warning:")
                        TextField("Seconds", value: $countDownWarning, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("seconds")
                    }
                    .onChange(of: countDownWarning) { _, newValue in
                        settings.countDownWarning = newValue
                        settings.save()
                    }
                }
            }
            .tabItem {
                Label("Audio", systemImage: "speaker.wave.2.fill")
            }
            .padding(20)
            
            // Outputs Settings
            MacOutputSettingsTab(outputManager: outputManager)
                .tabItem {
                    Label("Outputs", systemImage: "arrow.triangle.branch")
                }
                .padding(20)
            
            // Design Settings
            Form {
                Section("Cue Design") {
                    Toggle("Performance mode (protects levels during show)", isOn: $performanceMode)
                        .onChange(of: performanceMode) { _, newValue in
                            settings.performanceMode = newValue
                            settings.save()
                        }
                    
                    Toggle("Prompt for cue name when adding", isOn: $promptForCueName)
                        .onChange(of: promptForCueName) { _, newValue in
                            settings.promptForCueName = newValue
                            settings.save()
                        }
                    
                    Toggle("Auto-add effect when creating cue", isOn: $autoAddEffect)
                        .onChange(of: autoAddEffect) { _, newValue in
                            settings.autoAddEffect = newValue
                            settings.save()
                        }
                }
                
                Section("Remote") {
                    Toggle("Enable remote trigger (network)", isOn: $remoteTrigger)
                        .onChange(of: remoteTrigger) { _, newValue in
                            settings.remoteTrigger = newValue
                            settings.save()
                        }
                }
            }
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            .padding(20)
            
            // About
            VStack(spacing: 16) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                Text("FX Live Mac")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Professional Sound Effects Production")
                    .foregroundColor(.secondary)
                
                Text("Version 1.0")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
                
                Divider()
                    .frame(width: 200)
                
                Text("© 2012-2026 Driftwood Software")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("www.driftwoodsoftware.com")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        if let url = URL(string: "http://www.driftwoodsoftware.com") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                
                Spacer()
            }
            .padding(40)
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 600, height: 450)
    }
}

// MARK: - Output Settings Tab

struct MacOutputSettingsTab: View {
    @ObservedObject var outputManager: MacOutputManager
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Multi-Output Routing", isOn: Binding(
                    get: { outputManager.multiOutputEnabled },
                    set: { outputManager.setMultiOutputEnabled($0) }
                ))
                
                Text("When enabled, effects assigned to different outputs can be routed to separate audio devices or channel pairs on multi-channel interfaces.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if outputManager.multiOutputEnabled {
                Section("Output Bus Assignment") {
                    ForEach(0..<outputManager.buses.count, id: \.self) { busIndex in
                        MacOutputBusRow(
                            outputManager: outputManager,
                            busIndex: busIndex
                        )
                    }
                }
                
                Section {
                    HStack {
                        Button {
                            outputManager.addBus()
                        } label: {
                            Label("Add Output Bus", systemImage: "plus.circle")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            outputManager.removeLastBus()
                        } label: {
                            Label("Remove Last", systemImage: "minus.circle")
                        }
                        .buttonStyle(.bordered)
                        .disabled(outputManager.buses.count <= MacOutputManager.minimumBusCount)
                        
                        Spacer()
                        
                        Button("Refresh Devices") {
                            outputManager.enumerateDevices()
                        }
                        .buttonStyle(.bordered)
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
        .onAppear {
            outputManager.enumerateDevices()
        }
    }
}

struct MacOutputBusRow: View {
    @ObservedObject var outputManager: MacOutputManager
    let busIndex: Int
    
    /// The currently selected device (if any)
    private var selectedDevice: BASSOutputDevice? {
        let deviceIdx = outputManager.buses[busIndex].bassDeviceIndex
        return outputManager.availableDevices.first(where: { $0.id == deviceIdx })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                // Bus label
                Text("Output \(OutputBus.labelFor(busIndex))")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 80, alignment: .leading)
                
                // Device picker
                Picker("", selection: Binding(
                    get: { outputManager.buses[busIndex].bassDeviceIndex },
                    set: { outputManager.assignDevice(busIndex: busIndex, deviceIndex: $0) }
                )) {
                    Text("Default Output").tag(-1)
                    ForEach(outputManager.availableDevices) { device in
                        Text(device.displayName).tag(device.id)
                    }
                }
                .frame(minWidth: 200)
                
                // Channel pair picker (only shown for multi-channel devices)
                if let device = selectedDevice, device.channelPairs > 1 {
                    Picker("", selection: Binding(
                        get: { outputManager.buses[busIndex].channelPair },
                        set: { outputManager.assignChannelPair(busIndex: busIndex, channelPair: $0) }
                    )) {
                        ForEach(0..<device.channelPairs, id: \.self) { pair in
                            Text(BASSOutputDevice.channelPairLabel(pair)).tag(pair)
                        }
                    }
                    .frame(minWidth: 130)
                }
                
                // Status indicator
                Circle()
                    .fill(outputManager.buses[busIndex].isInitialised ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .help(outputManager.buses[busIndex].isInitialised ? "Active" : "Not configured")
                
                // Test button
                Button("Test") {
                    outputManager.testBus(busIndex)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!outputManager.buses[busIndex].isInitialised && outputManager.buses[busIndex].bassDeviceIndex < 0)
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
