//
//  FX_Live_MacApp.swift
//  FX-Live-Mac
//
//  Native macOS version of FX Live - Sound Effects Production
//

import SwiftUI
import AppKit

@main
struct FX_Live_MacApp: App {
    /// Delegate to handle app lifecycle events (termination cleanup)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Apply saved audio settings at launch
        fx.audio.logLevels = settings.logLevels
        fx.audio.globalVolume(0.5)  // 0.5 = 0 dB (unity gain)
        
        // Initialize app - load settings or install demo on first run
        initializeApp()
    }
    
    /// Initialize the app by loading settings and the last used show
    private func initializeApp() {
        print("🚀 FX_Live_MacApp.initializeApp() starting")
        let mgr = MacShowManager.shared
        
        // Load settings, or set defaults if first run
        if settings.load() {
            print("   ✅ Settings loaded - currentShow: '\(settings.currentShow)'")
        } else {
            print("   ⚠️ Settings not found - first time setup")
            settings.buyUnlimited = true
            settings.buyDSP = true
            settings.buyMIDI = true
            settings.buyMEDIA = true
            settings.buyMEDIA2 = true
            settings.firstTime = true
            settings.logLevels = true
            settings.save()
        }
        
        // Migrate any existing files from ~/Documents/ (from before per-show folders)
        mgr.migrateFromDocuments()
        
        // Ensure Demo Show is installed with all demo files
        mgr.reinstallDemoIfNeeded()
        
        // Get available shows from folder structure
        var showNames = mgr.allShowNames()
        
        // If still no shows, force demo install
        if showNames.isEmpty {
            print("   ⚠️ No shows found, forcing demo install")
            mgr.setCurrentShow("Demo Show")
            fx.install()
            settings.currentShow = "Demo Show"
            settings.save()
            showNames = mgr.allShowNames()
        }
        
        fx.showList = showNames
        print("   📂 Available shows: \(showNames)")
        
        // Select the last used show (or first available)
        if !settings.currentShow.isEmpty && showNames.contains(settings.currentShow) {
            mgr.setCurrentShow(settings.currentShow)
            fx.getLocalShows("")  // Populate mediaList from current show folder
            fx.selectShow(settings.currentShow)
            print("   ✅ Selected last used show: '\(settings.currentShow)'")
        } else if let firstShow = showNames.first {
            mgr.setCurrentShow(firstShow)
            fx.getLocalShows("")
            fx.selectShow(firstShow)
            settings.currentShow = firstShow
            settings.save()
            print("   ✅ Fallback to first show: '\(firstShow)'")
        } else {
            print("   ⚠️ No shows available")
        }
        
        print("   📋 fx.show.name: '\(fx.show.name)'")
        print("   📋 fx.show.currentVersion.cues.count: \(fx.show.currentVersion.cues.count)")
        
        // Initialise multi-output manager (loads saved bus assignments)
        Task { @MainActor in
            let outputMgr = MacOutputManager.shared
            outputMgr.enumerateDevices()
            outputMgr.loadSettings()
            print("   🔊 Output manager initialised, multiOutput=\(outputMgr.multiOutputEnabled)")
        }
        
        print("🚀 FX_Live_MacApp.initializeApp() complete\n")
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

// MARK: - App Delegate for Cleanup

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        print("🔊 App terminating — stopping all audio streams")
        // Stop all active effects and their additional streams
        for eff in fx.activeEffects {
            fx.audio.stop(eff.stream)
            eff.stopAdditionalStreams()
        }
        // Tear down all output bus mixers (frees BASS devices)
        MacOutputManager.shared.teardownAll()
    }
}
