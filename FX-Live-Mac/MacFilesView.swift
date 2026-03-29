//
//  MacFilesView.swift
//  FX-Live-Mac
//
//  Native macOS file management with drag-and-drop, rename, file info
//

import SwiftUI
import UniformTypeIdentifiers

struct MacFilesView: View {
    @State private var audioFiles: [String] = []
    @State private var searchText = ""
    @State private var isDragOver = false
    @State private var showingRenameAlert = false
    @State private var renameText = ""
    @State private var fileToRename = ""
    @State private var previewingFile = ""
    
    var filteredFiles: [String] {
        if searchText.isEmpty {
            return audioFiles
        }
        return audioFiles.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("AUDIO FILES")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(audioFiles.count) files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: importFiles) {
                    Label("Import", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search files...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                if previewingFile != "" {
                    Button(action: { stopPreview() }) {
                        Image(systemName: "stop.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            Divider()
            
            // File list with drag-and-drop
            List(filteredFiles, id: \.self) { file in
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(previewingFile == file ? .green : .blue)
                    
                    VStack(alignment: .leading) {
                        Text(file)
                            .font(.body)
                            .fontWeight(previewingFile == file ? .bold : .regular)
                        
                        HStack {
                            let ext = (file as NSString).pathExtension.uppercased()
                            Text(ext)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // File size
                            Text(fileSizeString(file))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Preview button
                    Button(action: { previewFile(file) }) {
                        Image(systemName: previewingFile == file ? "speaker.wave.2.fill" : "play.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(previewingFile == file ? .green : .primary)
                    
                    // Rename button
                    Button(action: {
                        fileToRename = file
                        renameText = (file as NSString).deletingPathExtension
                        showingRenameAlert = true
                    }) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)
                    
                    // Delete button
                    Button(action: { deleteFile(file) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .overlay {
                if isDragOver {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue, lineWidth: 3)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .padding(4)
                }
                
                if audioFiles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No audio files")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Drag audio files here or click Import")
                            .font(.body)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            }
            .onDrop(of: [.audio, .fileURL], isTargeted: $isDragOver) { providers in
                handleDrop(providers)
                return true
            }
        }
        .alert("Rename File", isPresented: $showingRenameAlert) {
            TextField("New name", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Rename") { renameFile() }
        } message: {
            Text("Enter a new name for the file")
        }
        .onAppear {
            loadFiles()
        }
    }
    
    private func loadFiles() {
        fx.getLocalShows("")
        audioFiles = fx.mediaList
        audioFiles.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    private func importFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio, .mpeg4Audio, .mpeg4Movie, .mp3, .wav, .aiff]
        panel.title = "Import Audio Files"
        
        panel.begin { response in
            if response == .OK {
                for url in panel.urls {
                    copyFileToDocuments(url)
                }
                loadFiles()
            }
        }
    }
    
    private func copyFileToDocuments(_ url: URL) {
        let destination = URL(fileURLWithPath: documentsPath(url.lastPathComponent))
        if !FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.copyItem(at: url, to: destination)
        }
    }
    
    private func previewFile(_ file: String) {
        let path = documentsPath(file)
        
        if fx.previewStream > 0 {
            fx.audio.stop(fx.previewStream)
        }
        
        if previewingFile == file {
            previewingFile = ""
            return
        }
        
        fx.previewStream = fx.audio.loadPreview(path)
        fx.audio.play(fx.previewStream)
        previewingFile = file
    }
    
    private func stopPreview() {
        if fx.previewStream > 0 {
            fx.audio.stop(fx.previewStream)
        }
        previewingFile = ""
    }
    
    private func deleteFile(_ file: String) {
        let path = documentsPath(file)
        try? FileManager.default.removeItem(atPath: path)
        if previewingFile == file { previewingFile = "" }
        loadFiles()
    }
    
    private func renameFile() {
        guard !renameText.isEmpty, !fileToRename.isEmpty else { return }
        let ext = (fileToRename as NSString).pathExtension
        let newName = renameText.appending(".\(ext)")
        let oldPath = documentsPath(fileToRename)
        let newPath = documentsPath(newName)
        
        do {
            try FileManager.default.moveItem(atPath: oldPath, toPath: newPath)
            loadFiles()
        } catch {
            print("Rename error: \(error)")
        }
    }
    
    private func fileSizeString(_ file: String) -> String {
        let path = documentsPath(file)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? UInt64 else { return "" }
        
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    copyFileToDocuments(url)
                    loadFiles()
                }
            }
        }
    }
}
