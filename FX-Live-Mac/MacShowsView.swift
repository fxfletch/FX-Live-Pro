//
//  MacShowsView.swift
//  FX-Live-Mac
//
//  Full Shows management view for macOS
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct MacShowsView: View {
    @StateObject private var viewModel = MacShowsViewModel()
    
    var body: some View {
        HSplitView {
            // Shows list
            VStack(spacing: 0) {
                HStack {
                    Text("SHOWS")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: { viewModel.showingNewShowAlert = true }) {
                        Image(systemName: "plus")
                    }
                }
                .padding()
                
                Divider()
                
                List(viewModel.shows, id: \.self, selection: $viewModel.selectedShow) { show in
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(show == viewModel.selectedShow ? .white : .blue)
                        Text(show)
                            .foregroundColor(show == viewModel.selectedShow ? .white : .primary)
                        Spacer()
                        if settings.currentShow == show {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(show == viewModel.selectedShow ? .white : .green)
                        }
                    }
                    .tag(show)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .onChange(of: viewModel.selectedShow) { _, newValue in
                    if let show = newValue {
                        viewModel.selectShow(show)
                    }
                }
            }
            .frame(minWidth: 220, maxWidth: 300)
            
            // Versions list
            VStack(spacing: 0) {
                HStack {
                    Text("VERSIONS")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: { viewModel.showingNewVersionAlert = true }) {
                        Image(systemName: "plus")
                    }
                }
                .padding()
                
                Divider()
                
                List(viewModel.versions.indices, id: \.self, selection: $viewModel.selectedVersionIndex) { index in
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(index == viewModel.selectedVersionIndex ? .white : .orange)
                        Text(viewModel.versions[index])
                            .foregroundColor(index == viewModel.selectedVersionIndex ? .white : .primary)
                    }
                    .tag(index)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .onChange(of: viewModel.selectedVersionIndex) { _, newValue in
                    if let idx = newValue {
                        viewModel.selectVersion(at: idx)
                    }
                }
            }
            .frame(minWidth: 180, maxWidth: 250)
            
            // Actions panel
            ScrollView {
                VStack(spacing: 16) {
                    // Show Management
                    GroupBox("Show Management") {
                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                Button("Rename Show") {
                                    viewModel.renameText = viewModel.selectedShowName
                                    viewModel.showingRenameShowAlert = true
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Delete Show") {
                                    viewModel.showingDeleteShowAlert = true
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .disabled(viewModel.shows.count <= 1)
                            }
                        }
                        .padding(8)
                    }
                    
                    // Version Management
                    GroupBox("Version Management") {
                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                Button("Rename Version") {
                                    viewModel.renameText = viewModel.selectedVersionName
                                    viewModel.showingRenameVersionAlert = true
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Delete Version") {
                                    viewModel.showingDeleteVersionAlert = true
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .disabled(viewModel.versions.count <= 1)
                            }
                        }
                        .padding(8)
                    }
                    
                    // Import / Export
                    GroupBox("Import / Export") {
                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                Button("Import Content") { viewModel.importContent() }
                                    .buttonStyle(.bordered)
                                Button("Export Archive") { viewModel.exportArchive() }
                                    .buttonStyle(.bordered)
                            }
                            HStack(spacing: 12) {
                                Button("Export Show Only") { viewModel.exportShowOnly() }
                                    .buttonStyle(.bordered)
                            }
                        }
                        .padding(8)
                    }
                    
                    // Print
                    GroupBox("Print") {
                        Button("Print Cue Sheet") { viewModel.printCueSheet() }
                            .buttonStyle(.bordered)
                            .padding(8)
                    }
                    
                    // Utilities
                    GroupBox("Utilities") {
                        Button("Delete Unused Media") {
                            viewModel.showingRecycleAlert = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .padding(8)
                    }
                    
                    // Links
                    GroupBox("Links & Support") {
                        HStack(spacing: 12) {
                            Button("YouTube") {
                                if let url = URL(string: "https://www.youtube.com/channel/UCzMIXacxpdJJMnrT955kszg") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Facebook") {
                                if let url = URL(string: "http://www.facebook.com/fxlive.users") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(8)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
        .alert("New Show", isPresented: $viewModel.showingNewShowAlert) {
            TextField("Show Name", text: $viewModel.newShowName)
            Button("Cancel", role: .cancel) { viewModel.newShowName = "" }
            Button("Create") { viewModel.createShow() }
        } message: {
            Text("Enter a name for the new show")
        }
        .alert("New Version", isPresented: $viewModel.showingNewVersionAlert) {
            TextField("Version Name", text: $viewModel.newVersionName)
            Button("Cancel", role: .cancel) { viewModel.newVersionName = "" }
            Button("Create") { viewModel.createVersion() }
        } message: {
            Text("Enter a name for the new version")
        }
        .alert("Rename Show", isPresented: $viewModel.showingRenameShowAlert) {
            TextField("Show Name", text: $viewModel.renameText)
            Button("Cancel", role: .cancel) { viewModel.renameText = "" }
            Button("Rename") { viewModel.renameShow() }
        } message: {
            Text("Enter a new name for the show")
        }
        .alert("Rename Version", isPresented: $viewModel.showingRenameVersionAlert) {
            TextField("Version Name", text: $viewModel.renameText)
            Button("Cancel", role: .cancel) { viewModel.renameText = "" }
            Button("Rename") { viewModel.renameVersion() }
        } message: {
            Text("Enter a new name for the version")
        }
        .confirmationDialog("Delete Show?", isPresented: $viewModel.showingDeleteShowAlert, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { viewModel.deleteShow() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to delete \(viewModel.selectedShowName)?")
        }
        .confirmationDialog("Delete Version?", isPresented: $viewModel.showingDeleteVersionAlert, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { viewModel.deleteVersion() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to delete \(viewModel.selectedVersionName)?")
        }
        .confirmationDialog("Delete Unused Media?", isPresented: $viewModel.showingRecycleAlert, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { viewModel.recycleMedia() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all media files not used in the current show. Make sure you have archived all shows you want to keep first.")
        }
        .confirmationDialog("Restore Archive?", isPresented: $viewModel.showingRestoreArchiveAlert, titleVisibility: .visible) {
            Button("Restore") { viewModel.restoreArchives() }
            Button("Cancel", role: .cancel) { viewModel.archivePathsToRestore = [] }
        } message: {
            Text("Do you want to restore \(viewModel.archivePathsToRestore.count) archive(s)? This will extract the show and all audio files into the app.")
        }
        .overlay {
            if viewModel.isRestoring {
                ZStack {
                    Color.black.opacity(0.4)
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Restoring Archive...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThickMaterial))
                }
            }
        }
        .onAppear {
            viewModel.loadShows()
        }
    }
}

// MARK: - View Model

@MainActor
class MacShowsViewModel: ObservableObject {
    @Published var shows: [String] = []
    @Published var versions: [String] = []
    @Published var selectedShow: String?
    @Published var selectedVersionIndex: Int?
    
    @Published var showingNewShowAlert = false
    @Published var showingNewVersionAlert = false
    @Published var showingRenameShowAlert = false
    @Published var showingRenameVersionAlert = false
    @Published var showingDeleteShowAlert = false
    @Published var showingDeleteVersionAlert = false
    @Published var showingRecycleAlert = false
    @Published var showingRestoreArchiveAlert = false
    @Published var archivePathsToRestore: [(path: String, ext: String)] = []
    @Published var importedShowName: String = ""
    @Published var isRestoring = false
    
    @Published var newShowName = ""
    @Published var newVersionName = ""
    @Published var renameText = ""
    
    var selectedShowName: String { selectedShow ?? "" }
    var selectedVersionName: String {
        guard let index = selectedVersionIndex, index < versions.count else { return "" }
        return versions[index]
    }
    
    func loadShows() {
        let mgr = MacShowManager.shared
        shows = mgr.allShowNames()
        fx.showList = shows
        // Populate mediaList from current show folder
        fx.getLocalShows("")
        selectedShow = settings.currentShow
        updateVersions()
    }
    
    func updateVersions() {
        versions = []
        for i in 0..<fx.show.totalVersions() {
            versions.append(fx.show.versionName(i))
        }
        selectedVersionIndex = fx.show.currentVersionNo
    }
    
    func selectShow(_ name: String) {
        MacShowManager.shared.setCurrentShow(name)
        fx.getLocalShows("")  // Refresh mediaList for new show folder
        fx.selectShow(name)
        selectedShow = name
        settings.currentShow = name
        settings.save()
        updateVersions()
    }
    
    func selectVersion(at index: Int) {
        fx.show.selectVersion(index)
        selectedVersionIndex = index
    }
    
    func createShow() {
        guard !newShowName.isEmpty else { return }
        let mgr = MacShowManager.shared
        mgr.createShowFolder(newShowName)
        mgr.setCurrentShow(newShowName)
        fx.createShow(newShowName)
        fx.show.write()
        shows = mgr.allShowNames()
        fx.showList = shows
        selectShow(newShowName)
        newShowName = ""
    }
    
    func createVersion() {
        guard !newVersionName.isEmpty else { return }
        fx.show.createVersion(newVersionName)
        fx.show.write()
        updateVersions()
        newVersionName = ""
    }
    
    func renameShow() {
        guard !renameText.isEmpty else { return }
        let oldName = fx.show.name
        let mgr = MacShowManager.shared
        
        // Rename the .fxLive file inside the folder
        let oldFile = documentsPath("\(oldName).fxLive")
        fx.show.name = renameText
        fx.show.write()  // Writes new .fxLive file
        try? FileManager.default.removeItem(atPath: oldFile)
        
        // Rename the show folder
        mgr.renameShowFolder(from: oldName, to: renameText)
        mgr.setCurrentShow(renameText)
        
        shows = mgr.allShowNames()
        fx.showList = shows
        selectedShow = renameText
        settings.currentShow = renameText
        settings.save()
        renameText = ""
    }
    
    func renameVersion() {
        guard !renameText.isEmpty else { return }
        fx.show.currentVersion.name = renameText
        fx.show.write()
        updateVersions()
        renameText = ""
    }
    
    func deleteShow() {
        guard shows.count > 1 else { return }
        let showName = settings.currentShow
        let mgr = MacShowManager.shared
        mgr.deleteShowFolder(showName)
        shows = mgr.allShowNames()
        fx.showList = shows
        if let firstShow = shows.first {
            selectShow(firstShow)
        }
    }
    
    func deleteVersion() {
        guard versions.count > 1 else { return }
        fx.show.deleteVersion()
        updateVersions()
    }
    
    func importContent() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .audio, .mpeg4Audio, .mp3, .wav, .aiff, .movie, .image,
            UTType(filenameExtension: "fxdoc") ?? .data,
            UTType(filenameExtension: "fxzip") ?? .data,
            UTType(filenameExtension: "fxLive") ?? .data,
            UTType(filenameExtension: "fxlive") ?? .data,
        ]
        panel.title = "Import Content"
        
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            
            var archivePaths: [(path: String, ext: String)] = []
            var importedShowName = ""
            
            for url in panel.urls {
                let name = url.lastPathComponent
                let ext = url.pathExtension.lowercased()
                
                // Archives (.fxdoc, .fxzip) go to a temp location for restore
                if ext == "fxdoc" || ext == "fxzip" {
                    let tempPath = NSTemporaryDirectory().appending(name)
                    do {
                        if FileManager.default.fileExists(atPath: tempPath) {
                            try FileManager.default.removeItem(atPath: tempPath)
                        }
                        try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: tempPath))
                        archivePaths.append((path: tempPath, ext: ext))
                    } catch {
                        print("Import error copying archive: \(error)")
                    }
                }
                // Show files (.fxLive) create a new show folder
                else if ext == "fxlive" {
                    let showName = (name as NSString).deletingPathExtension
                    let mgr = MacShowManager.shared
                    mgr.createShowFolder(showName)
                    mgr.setCurrentShow(showName)
                    let destPath = documentsPath(name)
                    do {
                        if FileManager.default.fileExists(atPath: destPath) {
                            try FileManager.default.removeItem(atPath: destPath)
                        }
                        try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destPath))
                        importedShowName = showName
                        print("Imported show: \(showName)")
                    } catch {
                        print("Import error: \(error)")
                    }
                }
                // Audio/media files go into the current show folder
                else {
                    let destPath = documentsPath(name)
                    do {
                        if FileManager.default.fileExists(atPath: destPath) {
                            try FileManager.default.removeItem(atPath: destPath)
                        }
                        try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destPath))
                        print("Imported media: \(name)")
                    } catch {
                        print("Import error: \(error)")
                    }
                }
            }
            
            DispatchQueue.main.async {
                let mgr = MacShowManager.shared
                self?.shows = mgr.allShowNames()
                fx.showList = self?.shows ?? []
                
                if !archivePaths.isEmpty {
                    self?.archivePathsToRestore = archivePaths
                    self?.showingRestoreArchiveAlert = true
                } else if !importedShowName.isEmpty {
                    self?.selectShow(importedShowName)
                } else {
                    // Refresh media list for current show
                    fx.getLocalShows("")
                }
            }
        }
    }
    
    func restoreArchives() {
        isRestoring = true
        let paths = archivePathsToRestore
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for archive in paths {
                print("Restoring archive: \(archive.path)")
                
                if archive.ext == "fxdoc" {
                    // .fxdoc is a FileWrapper bundle — extract to find the show name,
                    // create a show folder, then restore into it
                    let mgr = MacShowManager.shared
                    
                    // Determine show name from the archive filename
                    let archiveName = ((archive.path as NSString).lastPathComponent as NSString).deletingPathExtension
                    
                    DispatchQueue.main.sync {
                        mgr.createShowFolder(archiveName)
                        mgr.setCurrentShow(archiveName)
                    }
                    
                    // restoreArchive extracts to documentsPath() which is now the show folder
                    fx.show.restoreArchive(path: archive.path)
                    
                    // Clean up temp file
                    try? FileManager.default.removeItem(atPath: archive.path)
                    
                } else if archive.ext == "fxzip" {
                    let mgr = MacShowManager.shared
                    let archiveName = ((archive.path as NSString).lastPathComponent as NSString).deletingPathExtension
                    
                    DispatchQueue.main.sync {
                        mgr.createShowFolder(archiveName)
                        mgr.setCurrentShow(archiveName)
                    }
                    
                    fx.audio.unarchive(archive.path)
                    
                    try? FileManager.default.removeItem(atPath: archive.path)
                }
            }
            
            DispatchQueue.main.async {
                let mgr = MacShowManager.shared
                self?.shows = mgr.allShowNames()
                fx.showList = self?.shows ?? []
                self?.isRestoring = false
                self?.archivePathsToRestore = []
                
                // Select the last restored show
                if let lastArchive = paths.last {
                    let showName = ((lastArchive.path as NSString).lastPathComponent as NSString).deletingPathExtension
                    if mgr.showExists(showName) {
                        self?.selectShow(showName)
                    }
                }
            }
        }
    }
    
    func exportArchive() {
        fx.show.archiveShowTemp()
        let filePath = documentsPath("\(fx.show.name).fxdoc")
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(fx.show.name).fxdoc"
        panel.title = "Export Archive"
        
        panel.begin { response in
            if response == .OK, let destURL = panel.url {
                do {
                    try FileManager.default.copyItem(
                        at: URL(fileURLWithPath: filePath),
                        to: destURL
                    )
                } catch {
                    print("Export error: \(error)")
                }
            }
        }
    }
    
    func exportShowOnly() {
        let filePath = documentsPath("\(fx.show.name).fxLive")
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(fx.show.name).fxLive"
        panel.title = "Export Show"
        
        panel.begin { response in
            if response == .OK, let destURL = panel.url {
                do {
                    try FileManager.default.copyItem(
                        at: URL(fileURLWithPath: filePath),
                        to: destURL
                    )
                } catch {
                    print("Export error: \(error)")
                }
            }
        }
    }
    
    func printCueSheet() {
        var html = "<style>h1{text-align:center;font-family:Arial,Helvetica,sans-serif;}h2{font-family:Arial,Helvetica,sans-serif}h3{font-family:Arial,Helvetica,sans-serif}p{font-family:Arial,Helvetica,sans-serif}</style>"
        html += "<h1>FX Live Cue Sheet</h1>"
        html += "<h2>Show Name: <strong>\(fx.show.name)</strong></h2>"
        html += "<hr>"
        
        for cue in fx.show.currentVersion.cues {
            html += "<h3>\(cue.getName())<small> - \(formatSeconds(cue.duration()))</small></h3>"
            html += "<p>\(cue.notes)</p>"
            html += "<hr>"
        }
        html += "<br><p><small>Produced by FX Live 2 © Driftwood Software 2012-2026 - www.driftwoodsoftware.com</small></p>"
        
        let printInfo = NSPrintInfo.shared
        printInfo.topMargin = 72
        printInfo.bottomMargin = 72
        printInfo.leftMargin = 72
        printInfo.rightMargin = 72
        
        if let data = html.data(using: .utf8),
           let attrStr = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html,
                     .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        ) {
            let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 468, height: 648))
            textView.textStorage?.setAttributedString(attrStr)
            
            let printOp = NSPrintOperation(view: textView, printInfo: printInfo)
            printOp.showsPrintPanel = true
            printOp.showsProgressPanel = true
            printOp.run()
        }
    }
    
    func recycleMedia() {
        fx.show.recycle()
    }
}
