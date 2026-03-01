//
//  MacFilesView.swift
//  FX-Live-Mac
//
//  Native macOS file management with drag-and-drop from Finder
//

import SwiftUI
import UniformTypeIdentifiers

struct MacFilesView: View {
    @State private var audioFiles: [String] = []
    @State private var searchText = ""
    @State private var isDragOver = false
    
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
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            Divider()
            
            // File list with drag-and-drop
            List(filteredFiles, id: \.self) { file in
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text(file)
                            .font(.body)
                        
                        let ext = (file as NSString).pathExtension.uppercased()
                        Text(ext)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Preview button
                    Button(action: { previewFile(file) }) {
                        Image(systemName: "play.circle")
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
        panel.allowedContentTypes = [.audio, .mpeg4Audio, .mp3, .wav, .aiff]
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
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let destination = URL(fileURLWithPath: documentsPath).appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.copyItem(at: url, to: destination)
    }
    
    private func previewFile(_ file: String) {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let path = (documentsPath as NSString).appendingPathComponent(file)
        
        if fx.previewStream > 0 {
            fx.audio.stop(fx.previewStream)
        }
        fx.previewStream = fx.audio.loadPreview(path)
        fx.audio.play(fx.previewStream)
    }
    
    private func deleteFile(_ file: String) {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let path = (documentsPath as NSString).appendingPathComponent(file)
        fx.audio.myDeleteFile(path)
        loadFiles()
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
