//
//  MacMusicView.swift
//  FX-Live-Mac
//
//  Native macOS Music playlist view
//

import SwiftUI

struct MacMusicView: View {
    @StateObject private var viewModel = MacMusicViewModel()
    
    var body: some View {
        HSplitView {
            // Playlist
            VStack(spacing: 0) {
                HStack {
                    Text("MUSIC PLAYLIST")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(viewModel.tracks.count) tracks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button(action: { viewModel.addTrack() }) {
                        Image(systemName: "plus")
                    }
                }
                .padding()
                
                Divider()
                
                List(Array(viewModel.tracks.enumerated()), id: \.offset) { index, track in
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 25)
                        VStack(alignment: .leading) {
                            Text(track.name)
                                .font(.body)
                                .fontWeight(viewModel.currentTrackIndex == index ? .bold : .regular)
                            Text(viewModel.formatDuration(track.getDuration()))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if viewModel.currentTrackIndex == index && track.isPlaying() {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .listRowBackground(
                        viewModel.currentTrackIndex == index ? Color.green.opacity(0.2) : Color.clear
                    )
                    .onTapGesture {
                        viewModel.selectTrack(at: index)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
            .frame(minWidth: 280, maxWidth: 400)
            
            // Playback controls
            VStack(spacing: 20) {
                Spacer()
                
                // Now Playing
                if viewModel.currentTrackIndex >= 0 {
                    Text("Now Playing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.currentTrackName)
                        .font(.title2.bold())
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
                
                // Volume controls
                GroupBox {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Track Volume")
                                .font(.caption)
                            Slider(value: $viewModel.trackVolume, in: 0...1)
                            Text("\(Int(viewModel.trackVolume * 100))%")
                                .font(.caption.monospacedDigit())
                                .frame(width: 40)
                        }
                        
                        HStack {
                            Text("Music Master")
                                .font(.caption)
                            Slider(value: $viewModel.masterVolume, in: 0...1)
                            Text("\(Int(viewModel.masterVolume * 100))%")
                                .font(.caption.monospacedDigit())
                                .frame(width: 40)
                        }
                        
                        HStack {
                            Text("Fade Time")
                                .font(.caption)
                            Slider(value: $viewModel.fadeTime, in: 0...30)
                            Text(String(format: "%.1fs", viewModel.fadeTime))
                                .font(.caption.monospacedDigit())
                                .frame(width: 50)
                        }
                    }
                    .padding(4)
                }
                .padding(.horizontal, 40)
                
                // Playback buttons
                HStack(spacing: 12) {
                    Button("Fade") {
                        viewModel.fadeCurrentTrack()
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    
                    Button("Stop Next") {
                        viewModel.toggleStopNext()
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.stopNext ? .red : .gray)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            viewModel.loadPlaylist()
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
    
    private var timer: Timer?
    
    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDisplay()
            }
        }
    }
    
    deinit { timer?.invalidate() }
    
    func loadPlaylist() {
        tracks = fx.show.music
        currentTrackIndex = Int(fx.show.currentTrackNo)
        trackVolume = fx.show.currentTrack.level
        masterVolume = fx.show.musicLevel
        fadeTime = fx.show.musicFadeTime
    }
    
    func updateDisplay() {
        tracks = fx.show.music
        currentTrackIndex = Int(fx.show.currentTrackNo)
        if currentTrackIndex >= 0 && currentTrackIndex < tracks.count {
            currentTrackName = tracks[currentTrackIndex].name
            isPlaying = tracks[currentTrackIndex].isPlaying()
        }
    }
    
    func selectTrack(at index: Int) {
        fx.show.currentTrackNo = index
        currentTrackIndex = index
        updateDisplay()
    }
    
    func togglePlayPause() {
        if isPlaying {
            fx.audio.pauseEffect(fx.show.currentTrack.stream)
        } else {
            if fx.show.currentTrack.stream > 0 {
                fx.audio.playEffect(fx.show.currentTrack.stream)
            } else {
                fx.show.currentTrack.play(false)
            }
        }
        updateDisplay()
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
    
    func fadeCurrentTrack() {
        fx.show.currentTrack.fade(fadeTime, level: 0)
    }
    
    func toggleStopNext() {
        stopNext.toggle()
    }
    
    func addTrack() {
        // TODO: Open file browser to select audio
    }
    
    func formatDuration(_ seconds: Float) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
