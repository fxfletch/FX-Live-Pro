//
//  MacShowManager.swift
//  FX-Live-Mac
//
//  Manages per-show folders under ~/Library/Application Support/FX-Live-Mac/Shows/
//  Each show is a self-contained folder with the .fxLive file and all audio files.
//

import Foundation

class MacShowManager {
    static let shared = MacShowManager()
    
    /// The root directory for all shows
    let showsRoot: String
    
    /// The current show's folder path — this is what documentsPath() returns on Mac
    private(set) var currentShowFolder: String
    
    private init() {
        // ~/Library/Application Support/FX-Live-Mac/Shows/
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        showsRoot = (appSupport as NSString).appendingPathComponent("FX-Live-Mac/Shows")
        currentShowFolder = showsRoot // Default until a show is selected
        
        // Ensure the root directory exists
        try? FileManager.default.createDirectory(atPath: showsRoot, withIntermediateDirectories: true)
    }
    
    /// Set the current show folder. Creates the folder if it doesn't exist.
    func setCurrentShow(_ name: String) {
        let folder = (showsRoot as NSString).appendingPathComponent(name)
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        currentShowFolder = folder
        
        // Also update the ObjC side so audioEngine uses the same path
        MacShowManager_setObjCPath(folder)
        
        print("📁 Show folder set to: \(folder)")
    }
    
    /// Get all show names by listing subdirectories
    func allShowNames() -> [String] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: showsRoot) else { return [] }
        
        var shows: [String] = []
        for name in contents {
            let folder = (showsRoot as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: folder, isDirectory: &isDir), isDir.boolValue {
                // Check it contains a .fxLive file
                let fxLivePath = (folder as NSString).appendingPathComponent("\(name).fxLive")
                let fxlivePath = (folder as NSString).appendingPathComponent("\(name).fxlive")
                if fm.fileExists(atPath: fxLivePath) || fm.fileExists(atPath: fxlivePath) {
                    shows.append(name)
                }
            }
        }
        return shows.sorted()
    }
    
    /// Create a new show folder
    func createShowFolder(_ name: String) {
        let folder = (showsRoot as NSString).appendingPathComponent(name)
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
    }
    
    /// Delete a show folder and all its contents
    func deleteShowFolder(_ name: String) {
        let folder = (showsRoot as NSString).appendingPathComponent(name)
        try? FileManager.default.removeItem(atPath: folder)
    }
    
    /// Rename a show folder
    func renameShowFolder(from oldName: String, to newName: String) {
        let oldFolder = (showsRoot as NSString).appendingPathComponent(oldName)
        let newFolder = (showsRoot as NSString).appendingPathComponent(newName)
        try? FileManager.default.moveItem(atPath: oldFolder, toPath: newFolder)
    }
    
    /// Get the folder path for a specific show
    func folderForShow(_ name: String) -> String {
        return (showsRoot as NSString).appendingPathComponent(name)
    }
    
    /// Check if a show exists
    func showExists(_ name: String) -> Bool {
        let folder = folderForShow(name)
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: folder, isDirectory: &isDir) && isDir.boolValue
    }
    
    /// Check if a show folder actually has a .fxLive file in it
    func showHasData(_ name: String) -> Bool {
        let folder = folderForShow(name)
        let fxLivePath = (folder as NSString).appendingPathComponent("\(name).fxLive")
        let fxlivePath = (folder as NSString).appendingPathComponent("\(name).fxlive")
        return FileManager.default.fileExists(atPath: fxLivePath) || FileManager.default.fileExists(atPath: fxlivePath)
    }
    
    /// Migrate existing files from ~/Documents/ into per-show folders.
    /// This handles the transition from the old flat layout.
    func migrateFromDocuments() {
        let fm = FileManager.default
        let docsDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        
        print("🔄 Checking for files to migrate from ~/Documents/")
        
        // Find all .fxLive show files in ~/Documents/
        guard let contents = try? fm.contentsOfDirectory(atPath: docsDir) else { return }
        
        var showFiles: [String] = []
        var mediaFiles: [String] = []
        
        for file in contents {
            let lower = file.lowercased()
            if lower.hasSuffix(".fxlive") {
                showFiles.append(file)
            } else if lower.hasSuffix(".m4a") || lower.hasSuffix(".mp3") || lower.hasSuffix(".wav") ||
                        lower.hasSuffix(".aif") || lower.hasSuffix(".aiff") || lower.hasSuffix(".m4v") ||
                        lower.hasSuffix(".mov") || lower.hasSuffix(".mp4") {
                mediaFiles.append(file)
            }
        }
        
        guard !showFiles.isEmpty else {
            print("   No show files found in ~/Documents/, nothing to migrate")
            return
        }
        
        print("   Found \(showFiles.count) show(s) and \(mediaFiles.count) media file(s) to migrate")
        
        for showFile in showFiles {
            let showName = (showFile as NSString).deletingPathExtension
            let showFolder = folderForShow(showName)
            
            // Create the show folder
            try? fm.createDirectory(atPath: showFolder, withIntermediateDirectories: true)
            
            // Move the .fxLive file
            let srcPath = (docsDir as NSString).appendingPathComponent(showFile)
            let dstPath = (showFolder as NSString).appendingPathComponent(showFile)
            if !fm.fileExists(atPath: dstPath) {
                do {
                    try fm.moveItem(atPath: srcPath, toPath: dstPath)
                    print("   ✅ Moved show: \(showFile) -> \(showName)/")
                } catch {
                    // If move fails, try copy
                    try? fm.copyItem(atPath: srcPath, toPath: dstPath)
                    try? fm.removeItem(atPath: srcPath)
                    print("   ✅ Copied show: \(showFile) -> \(showName)/")
                }
            }
            
            // Copy media files into each show folder (they may be shared between shows)
            for mediaFile in mediaFiles {
                let mediaSrc = (docsDir as NSString).appendingPathComponent(mediaFile)
                let mediaDst = (showFolder as NSString).appendingPathComponent(mediaFile)
                if !fm.fileExists(atPath: mediaDst) {
                    try? fm.copyItem(atPath: mediaSrc, toPath: mediaDst)
                }
            }
        }
        
        // Clean up media files from ~/Documents/ after migration
        for mediaFile in mediaFiles {
            let path = (docsDir as NSString).appendingPathComponent(mediaFile)
            try? fm.removeItem(atPath: path)
            print("   🗑️ Removed from ~/Documents/: \(mediaFile)")
        }
        
        // Clean up any leftover .fxdoc, .fxzip files
        for file in contents {
            let lower = file.lowercased()
            if lower.hasSuffix(".fxdoc") || lower.hasSuffix(".fxzip") {
                let path = (docsDir as NSString).appendingPathComponent(file)
                try? fm.removeItem(atPath: path)
                print("   🗑️ Removed archive from ~/Documents/: \(file)")
            }
        }
        
        print("🔄 Migration complete")
    }
    
    /// Force reinstall the demo show by clearing the Demo Show folder
    /// and running fx.install() with the folder set as current
    func reinstallDemoIfNeeded() {
        let demoFolder = folderForShow("Demo Show")
        let fm = FileManager.default
        
        // Check if demo folder exists and has a .fxLive file
        if showHasData("Demo Show") {
            return  // Demo show already has data
        }
        
        print("📦 Installing demo show...")
        
        // Ensure the folder exists
        try? fm.createDirectory(atPath: demoFolder, withIntermediateDirectories: true)
        
        // Set the current show folder to Demo Show
        setCurrentShow("Demo Show")
        
        // Install demo files from bundle
        fx.install()
        
        print("📦 Demo show installed to \(demoFolder)")
    }
}

// MARK: - Bridge to ObjC

/// Sets the ObjC global path variable used by audioEngine.m
private func MacShowManager_setObjCPath(_ path: String) {
    setMacOSShowFolder(path)
}
