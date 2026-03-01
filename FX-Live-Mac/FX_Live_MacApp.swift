//
//  FX_Live_MacApp.swift
//  FX-Live-Mac
//
//  Native macOS version of FX Live - Sound Effects Production
//

import SwiftUI

@main
struct FX_Live_MacApp: App {
    
    init() {
        // Apply saved audio settings at launch
        fx.audio.logLevels = settings.logLevels
        fx.audio.globalVolume(10000)
        
        // Load settings
        _ = settings.load()
    }
    
    var body: some Scene {
        // Main application window
        WindowGroup {
            ContentView()
                .frame(minWidth: 1200, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1400, height: 900)
        
        // Secondary window for full-screen perform mode
        Window("Perform", id: "perform-window") {
            MacPerformView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)
        
        // Settings window
        Settings {
            MacSettingsView()
        }
    }
}
