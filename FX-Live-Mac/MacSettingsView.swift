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
        .frame(width: 500, height: 350)
    }
}
