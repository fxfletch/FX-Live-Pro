//
//  MacMusicView.swift
//  FX-Live-Mac
//
//  Native macOS Music playlist view with spot effects
//

import SwiftUI

struct MacMusicView: View {
    @StateObject private var viewModel = MacMusicViewModel()
    
    var body: some View {
        HSplitView {
            // Left: Playlist
            VStack(spacing: 0) {
                HStack {
                    Text("MUSIC PLAYLIST")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    if !viewModel.tracks.isEmpty {
                        Text("\(viewModel.tracks.count) tracks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Button(action: { viewModel.addTrack() }) {
                        Image(systemName: "plus")
                    }
                    Button(action: { viewModel.showingEmptyAlert = true }) {
                        Image(systemName: "trash")
                    }
                    .disabled(viewModel.tracks.isEmpty)
                }
                .padding()
                
                Divider()
                
                if viewModel.tracks.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Music")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Click + to add music to your playlist")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(Array(viewModel.tracks.enumerated()), id: \.offset) { index, track in
                        HStack {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                                .frame(width: 25)
                            VStack(alignment: .leading) {
                                Text(track.name.isEmpty ? "Untitled" : track.name)
                                    .font(.body)
                                    .fontWeight(viewModel.currentTrackIndex == index ? .bold : .regular)
                                Text(viewModel.formatDuration(track.getDuration()))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if !track.isValid() {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                            }
                            if viewModel.currentTrackIndex == index && track.isPlaying() {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .listRowBackground(
                            viewModel.currentTrackIndex == index ? Color.green.opacity(0.2) : Color.clear
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectTrack(at: index)
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }
            .frame(minWidth: 280, maxWidth: 400)
            
            // Right: Controls + Spot Effects
            VStack(spacing: 0) {
                // Playback controls
                VStack(spacing: 16) {
                    // Now Playing
                    if viewModel.currentTrackIndex >= 0 && viewModel.currentTrackIndex < viewModel.tracks.count {
                        VStack(spacing: 4) {
                            Text("Now Playing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(viewModel.currentTrackName)
                                .font(.title2.bold())
                                .lineLimit(1)
                        }
                    }
                    
                    // Transport
                    HStack(spacing: 24) {
                        Button(action: { viewModel.previousTrack() }) {
                            Image(systemName: "backward.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { viewModel.togglePlayPause() }) {
                            Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 48))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { viewModel.nextTrack() }) {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Remaining time
                    if viewModel.isPlaying {
                        Text("Remaining: \(viewModel.formatDuration(Float(viewModel.remainingTime)))")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    
                    // Volume controls
                    GroupBox {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Track Volume")
                                    .font(.caption)
                                    .frame(width: 90, alignment: .leading)
                                Slider(value: Binding(
                                    get: { Double(viewModel.trackVolume) },
                                    set: { viewModel.updateTrackVolume(Float($0)) }
                                ), in: 0...1)
                                Text("\(Int(viewModel.trackVolume * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .frame(width: 40)
                            }
                            
                            HStack {
                                Text("Music Master")
                                    .font(.caption)
                                    .frame(width: 90, alignment: .leading)
                                Slider(value: Binding(
                                    get: { Double(viewModel.masterVolume) },
                                    set: { viewModel.updateMasterVolume(Float($0)) }
                                ), in: 0...1)
                                Text("\(Int(viewModel.masterVolume * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .frame(width: 40)
                            }
                            
                            HStack {
                                Text("Fade Time")
                                    .font(.caption)
                                    .frame(width: 90, alignment: .leading)
                                Slider(value: Binding(
                                    get: { Double(viewModel.fadeTime) },
                                    set: { viewModel.updateFadeTime(Float($0)) }
                                ), in: 0...30)
                                Text(String(format: "%.1fs", viewModel.fadeTime))
                                    .font(.caption.monospacedDigit())
                                    .frame(width: 50)
                            }
                        }
                        .padding(4)
                    }
                    .padding(.horizontal, 20)
                    
                    // Playback buttons
                    HStack(spacing: 12) {
                        Button("Fade") { viewModel.fade() }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            .disabled(!viewModel.isPlaying)
                        
                        Button("Stop Next") { viewModel.toggleStopNext() }
                            .buttonStyle(.bordered)
                            .tint(viewModel.stopNext ? .red : .gray)
                    }
                }
                .padding()
                
                Divider()
                
                // Spot Effects
                ScrollView {
                    VStack(spacing: 16) {
                        // Spot Effects (indices 0-3)
                        GroupBox("Spot Effects") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(0..<4, id: \.self) { index in
                                    MacSpotButton(
                                        index: index,
                                        name: viewModel.spotNames[index],
                                        hasFile: viewModel.spotHasFile[index],
                                        isActive: viewModel.spotActive[index],
                                        onTap: { viewModel.toggleSpotEffect(at: index) },
                                        onSelect: { viewModel.selectSpotFile(at: index) },
                                        onClear: { viewModel.clearSpotEffect(at: index) }
                                    )
                                }
                            }
                            .padding(4)
                        }
                        .padding(.horizontal)
                        
                        // Announcements (indices 4-7)
                        GroupBox("Announcements") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(0..<4, id: \.self) { index in
                                    MacSpotButton(
                                        index: index + 4,
                                        name: viewModel.announcementNames[index],
                                        hasFile: viewModel.announcementHasFile[index],
                                        isActive: viewModel.announcementActive[index],
                                        onTap: { viewModel.toggleAnnouncement(at: index) },
                                        onSelect: { viewModel.selectAnnouncementFile(at: index) },
                                        onClear: { viewModel.clearAnnouncement(at: index) }
                                    )
                                }
                            }
                            .padding(4)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog("Empty Playlist?", isPresented: $viewModel.showingEmptyAlert, titleVisibility: .visible) {
            Button("Empty", role: .destructive) { viewModel.emptyPlaylist() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to empty the music playlist?")
        }
        .onAppear {
            viewModel.loadPlaylist()
        }
    }
}

// MARK: - Spot Button

struct MacSpotButton: View {
    let index: Int
    let name: String
    let hasFile: Bool
    let isActive: Bool
    let onTap: () -> Void
    let onSelect: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(index < 4 ? index + 1 : index - 3)")
                .font(.caption2)
                .fontWeight(.semibold)
            
            if !hasFile {
                Image(systemName: "plus.circle")
                    .font(.title3)
            } else {
                Text(name.isEmpty ? "Spot \(index + 1)" : name)
                    .font(.caption)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.green.opacity(0.3) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.green : Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if hasFile { onTap() } else { onSelect() }
        }
        .contextMenu {
            if hasFile {
                Button("Clear") { onClear() }
            }
            Button("Select File...") { onSelect() }
        }
    }
}

// MARK: - View Model

@MainActor
class MacMusicViewModel: ObservableObject {
    @Published var tracks: [FxEffect] = []
    @Published var currentTrackIndex: Int = -1
    @Published var currentTrackName = ""
    @Published var isPlaying = false
    @Published var trackVolume: Float = 1.0
    @Published var masterVolume: Float = 1.0
    @Published var fadeTime: Float = 5.0
    @Published var stopNext = false
    @Published var remainingTime: Double = 0
    @Published var showingEmptyAlert = false
    
    // Spot effects
    @Published var spotNames: [String] = ["", "", "", ""]
    @Published var spotHasFile: [Bool] = [false, false, false, false]
    @Published var spotActive: [Bool] = [false, false, false, false]
    @Published var announcementNames: [String] = ["", "", "", ""]
    @Published var announcementHasFile: [Bool] = [false, false, false, false]
    @Published var announcementActive: [Bool] = [false, false, false, false]
    
    private var timer: Timer?
    
    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDisplay()
            }
        }
    }
    
    deinit { timer?.invalidate() }
    
    func loadPlaylist() {
        tracks = Array(fx.show.music)
        currentTrackIndex = fx.show.currentTrackNo
        trackVolume = fx.show.currentTrack.level
        masterVolume = fx.show.musicLevel
        fadeTime = fx.show.musicFadeTime
        stopNext = fx.show.musicStopPending
        updateSpotData()
    }
    
    func updateDisplay() {
        if fx.show.processMusic() {
            tracks = Array(fx.show.music)
            currentTrackIndex = fx.show.currentTrackNo
        }
        
        if tracks.count != fx.show.music.count || currentTrackIndex != fx.show.currentTrackNo {
            loadPlaylist()
        }
        
        isPlaying = fx.show.currentTrack.isPlaying()
        stopNext = fx.show.musicStopPending
        masterVolume = fx.show.musicLevel
        
        if currentTrackIndex >= 0 && currentTrackIndex < tracks.count {
            currentTrackName = tracks[currentTrackIndex].name
        }
        
        if isPlaying {
            let position = fx.show.currentTrack.getPosition()
            remainingTime = max(0, Double(fx.show.currentTrack.outPoint - position))
        }
        
        // Update spot active states
        for i in 0..<4 {
            if i < fx.show.spotEffects.count {
                let playing = fx.show.spotEffects[i].isPlaying()
                if spotActive[i] != playing { spotActive[i] = playing }
            }
            let annIdx = i + 4
            if annIdx < fx.show.spotEffects.count {
                let playing = fx.show.spotEffects[annIdx].isPlaying()
                if announcementActive[i] != playing { announcementActive[i] = playing }
            }
        }
    }
    
    private func updateSpotData() {
        for i in 0..<4 {
            if i < fx.show.spotEffects.count {
                spotNames[i] = fx.show.spotEffects[i].name
                spotHasFile[i] = !fx.show.spotEffects[i].file.isEmpty
                spotActive[i] = fx.show.spotEffects[i].isPlaying()
            }
            let annIdx = i + 4
            if annIdx < fx.show.spotEffects.count {
                announcementNames[i] = fx.show.spotEffects[annIdx].name
                announcementHasFile[i] = !fx.show.spotEffects[annIdx].file.isEmpty
                announcementActive[i] = fx.show.spotEffects[annIdx].isPlaying()
            }
        }
    }
    
    func selectTrack(at index: Int) {
        fx.show.selectTrack(index)
        loadPlaylist()
    }
    
    func togglePlayPause() {
        if fx.show.currentTrack.isPlaying() {
            fx.show.currentTrack.stop()
        } else {
            fx.show.currentTrack.play(true)
        }
    }
    
    func previousTrack() {
        if currentTrackIndex > 0 {
            selectTrack(at: currentTrackIndex - 1)
        }
    }
    
    func nextTrack() {
        if currentTrackIndex < tracks.count - 1 {
            selectTrack(at: currentTrackIndex + 1)
        }
    }
    
    func fade() {
        if fx.show.currentTrack.isPlaying() {
            fx.show.currentTrack.fade(fx.show.musicFadeTime, level: fx.show.currentTrack.level * fx.show.musicLevel)
        }
    }
    
    func toggleStopNext() {
        fx.show.musicStopPending = !fx.show.musicStopPending
        stopNext = fx.show.musicStopPending
    }
    
    func addTrack() {
        fx.show.addMusic()
        fx.activeEffect = fx.show.currentTrack
        fx.activeEffect.music = true
        
        // Open file browser
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio, .mpeg4Audio, .mp3, .wav, .aiff]
        panel.title = "Select Music Track"
        panel.directoryURL = URL(fileURLWithPath: documentsPath())
        
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            DispatchQueue.main.async {
                let fileName = url.lastPathComponent
                let destPath = documentsPath(fileName)
                
                if !FileManager.default.fileExists(atPath: destPath) {
                    try? FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destPath))
                }
                
                fx.activeEffect.file = fileName
                fx.activeEffect.name = (fileName as NSString).deletingPathExtension
                fx.activeEffect.type = fx.TYPE_AUDIO
                
                let stream = fx.audio.loadPreview(destPath)
                if stream > 0 {
                    fx.activeEffect.outPoint = Float(fx.audio.getDur(stream))
                    fx.audio.stop(stream)
                }
                
                fx.show.save()
                self?.loadPlaylist()
            }
        }
    }
    
    func emptyPlaylist() {
        fx.show.music.removeAll(keepingCapacity: false)
        loadPlaylist()
    }
    
    func updateTrackVolume(_ volume: Float) {
        trackVolume = volume
        fx.show.currentTrack.level = volume
        let combined = volume * masterVolume
        fx.audio.setLevel(fx.show.currentTrack.stream, level: combined)
        fx.show.save()
    }
    
    func updateMasterVolume(_ volume: Float) {
        masterVolume = volume
        fx.show.musicLevel = volume
        let combined = trackVolume * volume
        fx.audio.setLevel(fx.show.currentTrack.stream, level: combined)
        fx.show.save()
    }
    
    func updateFadeTime(_ time: Float) {
        fadeTime = time
        fx.show.musicFadeTime = time
        fx.show.write()
    }
    
    // Spot effects
    func toggleSpotEffect(at index: Int) {
        guard index < fx.show.spotEffects.count else { return }
        if fx.show.spotEffects[index].isPlaying() {
            fx.show.spotEffects[index].stop()
        } else {
            fx.show.spotEffects[index].spotPlay()
        }
    }
    
    func clearSpotEffect(at index: Int) {
        guard index < fx.show.spotEffects.count else { return }
        if fx.show.spotEffects[index].isPlaying() { fx.show.spotEffects[index].stop() }
        fx.show.spotEffects[index] = FxEffect()
        fx.show.save()
        updateSpotData()
    }
    
    func selectSpotFile(at index: Int) {
        guard index < fx.show.spotEffects.count else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio, .mpeg4Audio, .mp3, .wav, .aiff]
        panel.title = "Select Spot Effect"
        panel.directoryURL = URL(fileURLWithPath: documentsPath())
        
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            DispatchQueue.main.async {
                let fileName = url.lastPathComponent
                let destPath = documentsPath(fileName)
                if !FileManager.default.fileExists(atPath: destPath) {
                    try? FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destPath))
                }
                fx.show.spotEffects[index].file = fileName
                fx.show.spotEffects[index].name = (fileName as NSString).deletingPathExtension
                fx.show.spotEffects[index].type = fx.TYPE_AUDIO
                let stream = fx.audio.loadPreview(destPath)
                if stream > 0 {
                    fx.show.spotEffects[index].outPoint = Float(fx.audio.getDur(stream))
                    fx.audio.stop(stream)
                }
                fx.show.save()
                self?.updateSpotData()
            }
        }
    }
    
    func toggleAnnouncement(at index: Int) {
        let spotIdx = index + 4
        guard spotIdx < fx.show.spotEffects.count else { return }
        if fx.show.spotEffects[spotIdx].isPlaying() {
            fx.show.spotEffects[spotIdx].stop()
        } else {
            fx.show.spotEffects[spotIdx].spotPlay()
        }
    }
    
    func clearAnnouncement(at index: Int) {
        let spotIdx = index + 4
        guard spotIdx < fx.show.spotEffects.count else { return }
        if fx.show.spotEffects[spotIdx].isPlaying() { fx.show.spotEffects[spotIdx].stop() }
        fx.show.spotEffects[spotIdx] = FxEffect()
        fx.show.save()
        updateSpotData()
    }
    
    func selectAnnouncementFile(at index: Int) {
        let spotIdx = index + 4
        guard spotIdx < fx.show.spotEffects.count else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio, .mpeg4Audio, .mp3, .wav, .aiff]
        panel.title = "Select Announcement"
        panel.directoryURL = URL(fileURLWithPath: documentsPath())
        
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            DispatchQueue.main.async {
                let fileName = url.lastPathComponent
                let destPath = documentsPath(fileName)
                if !FileManager.default.fileExists(atPath: destPath) {
                    try? FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destPath))
                }
                fx.show.spotEffects[spotIdx].file = fileName
                fx.show.spotEffects[spotIdx].name = (fileName as NSString).deletingPathExtension
                fx.show.spotEffects[spotIdx].type = fx.TYPE_AUDIO
                let stream = fx.audio.loadPreview(destPath)
                if stream > 0 {
                    fx.show.spotEffects[spotIdx].outPoint = Float(fx.audio.getDur(stream))
                    fx.audio.stop(stream)
                }
                fx.show.save()
                self?.updateSpotData()
            }
        }
    }
    
    func formatDuration(_ seconds: Float) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
