//
//  MacSettingsView.swift
//  FX-Live-Mac
//
//  macOS Settings window
//

import SwiftUI

struct MacSettingsView: View {
    @State private var logLevels = settings.logLevels
    @State private var countDownWarning = settings.countDownWarning
    @State private var resetToStart = settings.resetToStart
    
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
                
                Spacer()
            }
            .padding(40)
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 450, height: 300)
    }
}
