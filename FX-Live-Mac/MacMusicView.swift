//
//  MacMusicView.swift
//  FX-Live-Mac
//
//  Native macOS Music playlist view with spot effects
//

import SwiftUI
import AVFoundation

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
                        .contextMenu {
                            Button {
                                viewModel.moveTrackUp(from: index)
                            } label: {
                                Label("Move Up", systemImage: "arrow.up")
                            }
                            .disabled(index == 0)
                            
                            Button {
                                viewModel.moveTrackDown(from: index)
                            } label: {
                                Label("Move Down", systemImage: "arrow.down")
                            }
                            .disabled(index >= viewModel.tracks.count - 1)
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                viewModel.deleteTrack(at: index)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    
                    Divider()
                    
                    // Playlist toolbar
                    HStack(spacing: 8) {
                        Button(action: { viewModel.moveCurrentTrackUp() }) {
                            Image(systemName: "arrow.up")
                        }
                        .disabled(viewModel.currentTrackIndex <= 0)
                        .help("Move Track Up")
                        
                        Button(action: { viewModel.moveCurrentTrackDown() }) {
                            Image(systemName: "arrow.down")
                        }
                        .disabled(viewModel.currentTrackIndex < 0 || viewModel.currentTrackIndex >= viewModel.tracks.count - 1)
                        .help("Move Track Down")
                        
                        Spacer()
                        
                        Button(action: { viewModel.deleteCurrentTrack() }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .disabled(viewModel.currentTrackIndex < 0 || viewModel.tracks.isEmpty)
                        .help("Delete Track")
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
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
                
                // Spot Effects & Announcements
                ScrollView {
                    VStack(spacing: 16) {
                        // Inline Properties Editor (shown when editing a spot)
                        if let editIdx = viewModel.editingSpotIndex {
                            MacSpotPropertiesEditor(
                                spotIndex: editIdx,
                                isSpotEffect: editIdx < 4,
                                viewModel: viewModel
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // Spot Effects (indices 0-3)
                        GroupBox("Spot Effects") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(0..<4, id: \.self) { index in
                                    MacSpotButton(
                                        index: index,
                                        name: viewModel.spotNames[index],
                                        hasFile: viewModel.spotHasFile[index],
                                        isActive: viewModel.spotActive[index],
                                        isEditing: viewModel.editingSpotIndex == index,
                                        onTap: { viewModel.toggleSpotEffect(at: index) },
                                        onSelect: { viewModel.selectSpotFile(at: index) },
                                        onClear: { viewModel.clearSpotEffect(at: index) },
                                        onEdit: { viewModel.editSpotEffect(at: index) },
                                        onRename: { viewModel.startRenaming(spotIndex: index) }
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
                                        isEditing: viewModel.editingSpotIndex == index + 4,
                                        onTap: { viewModel.toggleAnnouncement(at: index) },
                                        onSelect: { viewModel.selectAnnouncementFile(at: index) },
                                        onClear: { viewModel.clearAnnouncement(at: index) },
                                        onEdit: { viewModel.editSpotEffect(at: index + 4) },
                                        onRename: { viewModel.startRenaming(spotIndex: index + 4) }
                                    )
                                }
                            }
                            .padding(4)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.editingSpotIndex)
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
        .alert("Rename", isPresented: $viewModel.showingRenameAlert) {
            TextField("Name", text: $viewModel.renameText)
            Button("OK") {
                viewModel.confirmRename()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for this effect")
        }
        .onAppear {
            viewModel.loadPlaylist()
        }
        // Keyboard shortcuts matching the Mac Perform view pattern
        .background(musicKeyboardShortcuts)
    }
    
    // MARK: - Keyboard Shortcuts
    
    /// Hidden buttons providing keyboard shortcuts for music and spot effect control
    @ViewBuilder
    private var musicKeyboardShortcuts: some View {
        // Space = Play/Pause music
        Button("") { viewModel.togglePlayPause() }
            .keyboardShortcut(.space, modifiers: [])
            .hidden()
        
        // F = Fade
        Button("") { viewModel.fade() }
            .keyboardShortcut(KeyEquivalent("f"), modifiers: [])
            .hidden()
        
        // N = Stop Next toggle
        Button("") { viewModel.toggleStopNext() }
            .keyboardShortcut(KeyEquivalent("n"), modifiers: [])
            .hidden()
        
        // S = Stop (emergency stop current track)
        Button("") {
            if viewModel.isPlaying {
                fx.show.currentTrack.stop()
            }
        }
            .keyboardShortcut(KeyEquivalent("s"), modifiers: [])
            .hidden()
        
        // Left Arrow = Previous track
        Button("") { viewModel.previousTrack() }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .hidden()
        
        // Right Arrow = Next track
        Button("") { viewModel.nextTrack() }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .hidden()
        
        // 1-4 = Spot Effects
        Button("") { viewModel.toggleSpotEffect(at: 0) }
            .keyboardShortcut(KeyEquivalent("1"), modifiers: [])
            .hidden()
        
        Button("") { viewModel.toggleSpotEffect(at: 1) }
            .keyboardShortcut(KeyEquivalent("2"), modifiers: [])
            .hidden()
        
        Button("") { viewModel.toggleSpotEffect(at: 2) }
            .keyboardShortcut(KeyEquivalent("3"), modifiers: [])
            .hidden()
        
        Button("") { viewModel.toggleSpotEffect(at: 3) }
            .keyboardShortcut(KeyEquivalent("4"), modifiers: [])
            .hidden()
        
        // 5-8 = Announcements
        Button("") { viewModel.toggleAnnouncement(at: 0) }
            .keyboardShortcut(KeyEquivalent("5"), modifiers: [])
            .hidden()
        
        Button("") { viewModel.toggleAnnouncement(at: 1) }
            .keyboardShortcut(KeyEquivalent("6"), modifiers: [])
            .hidden()
        
        Button("") { viewModel.toggleAnnouncement(at: 2) }
            .keyboardShortcut(KeyEquivalent("7"), modifiers: [])
            .hidden()
        
        Button("") { viewModel.toggleAnnouncement(at: 3) }
            .keyboardShortcut(KeyEquivalent("8"), modifiers: [])
            .hidden()
    }
}

// MARK: - Spot Button

struct MacSpotButton: View {
    let index: Int
    let name: String
    let hasFile: Bool
    let isActive: Bool
    let isEditing: Bool
    let onTap: () -> Void
    let onSelect: () -> Void
    let onClear: () -> Void
    let onEdit: () -> Void
    let onRename: () -> Void
    
    private var displayNumber: Int {
        index < 4 ? index + 1 : index - 3
    }
    
    private var buttonColor: Color {
        if isEditing { return .accentColor }
        if isActive { return .green }
        return index < 4 ? .blue : .purple
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(displayNumber)")
                .font(.caption2)
                .fontWeight(.semibold)
            
            if !hasFile {
                Image(systemName: "plus.circle")
                    .font(.title3)
            } else {
                Text(name.isEmpty ? (index < 4 ? "Spot \(displayNumber)" : "Announce \(displayNumber)") : name)
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
                .fill(isEditing ? buttonColor.opacity(0.15) : (isActive ? Color.green.opacity(0.3) : Color(nsColor: .controlBackgroundColor)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isEditing ? buttonColor : (isActive ? Color.green : Color.secondary.opacity(0.3)), lineWidth: isEditing ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if hasFile { onTap() } else { onSelect() }
        }
        .contextMenu {
            if hasFile {
                Button {
                    onEdit()
                } label: {
                    Label("Edit Properties", systemImage: "slider.horizontal.3")
                }
                
                Button {
                    onRename()
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                
                Divider()
                
                Button {
                    onSelect()
                } label: {
                    Label("Change File...", systemImage: "doc.badge.arrow.up")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    onClear()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
            } else {
                Button {
                    onSelect()
                } label: {
                    Label("Select File...", systemImage: "doc.badge.plus")
                }
            }
        }
    }
}

// MARK: - Spot Effect Properties Editor

struct MacSpotPropertiesEditor: View {
    let spotIndex: Int
    let isSpotEffect: Bool // true = spot effect (0-3), false = announcement (4-7)
    @ObservedObject var viewModel: MacMusicViewModel
    @State private var isRenaming = false
    @State private var renameText = ""
    
    private var effect: FxEffect {
        fx.show.spotEffects[spotIndex]
    }
    
    private var displayName: String {
        let name = effect.name
        if name.isEmpty || name == "New Event" {
            return isSpotEffect ? "Spot Effect \(spotIndex + 1)" : "Announcement \(spotIndex - 3)"
        }
        return name
    }
    
    private var accentColor: Color {
        isSpotEffect ? .blue : .purple
    }
    
    var body: some View {
        GroupBox {
            VStack(spacing: 12) {
                // Header with name and close
                HStack {
                    Image(systemName: isSpotEffect ? "speaker.wave.2.fill" : "megaphone.fill")
                        .foregroundColor(accentColor)
                    
                    if isRenaming {
                        TextField("Name", text: $renameText, onCommit: {
                            viewModel.renameSpotEffect(at: spotIndex, name: renameText)
                            isRenaming = false
                        })
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                        
                        Button("Done") {
                            viewModel.renameSpotEffect(at: spotIndex, name: renameText)
                            isRenaming = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Text(displayName)
                            .font(.headline)
                        
                        Button {
                            renameText = effect.name
                            isRenaming = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Playing indicator
                    if effect.isPlaying() {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Playing")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Button {
                        viewModel.editingSpotIndex = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                
                // File info
                HStack {
                    Text("File")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)
                    Text(effect.file.isEmpty ? "No file selected" : effect.file)
                        .font(.caption)
                        .foregroundColor(effect.file.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Change...") {
                        viewModel.selectSpotFile(at: spotIndex)
                    }
                    .controlSize(.small)
                }
                
                // Duration info
                if effect.outPoint > 0 {
                    HStack {
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .leading)
                        Text(viewModel.formatDuration(effect.getDuration()))
                            .font(.caption.monospacedDigit())
                        if viewModel.spotFileDuration > 0 && effect.getDuration() < viewModel.spotFileDuration {
                            Text("(of \(viewModel.formatDuration(viewModel.spotFileDuration)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                
                // Waveform Trim View
                if viewModel.spotFileDuration > 0 {
                    MacSpotWaveformTrimView(viewModel: viewModel)
                        .padding(.vertical, 4)
                }
                
                Divider()
                
                // Level
                HStack {
                    Text("Level")
                        .font(.caption)
                        .frame(width: 70, alignment: .leading)
                    Slider(value: Binding(
                        get: { Double(effect.level) },
                        set: { viewModel.updateSpotLevel(at: spotIndex, level: Float($0)) }
                    ), in: 0...1)
                    Text("\(Int(effect.level * 100))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 40)
                }
                
                // Pan
                HStack {
                    Text("Pan")
                        .font(.caption)
                        .frame(width: 70, alignment: .leading)
                    Slider(value: Binding(
                        get: { Double(effect.pan) },
                        set: { viewModel.updateSpotPan(at: spotIndex, pan: Float($0)) }
                    ), in: -1...1)
                    Text(panLabel(effect.pan))
                        .font(.caption.monospacedDigit())
                        .frame(width: 40)
                }
                
                Divider()
                
                // Fade In / Fade Out
                HStack(spacing: 16) {
                    HStack {
                        Text("Fade In")
                            .font(.caption)
                            .frame(width: 50, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(effect.inTrans) },
                            set: { viewModel.updateSpotFadeIn(at: spotIndex, time: Float($0)) }
                        ), in: 0...30)
                        Text(String(format: "%.1fs", effect.inTrans))
                            .font(.caption.monospacedDigit())
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Fade Out")
                            .font(.caption)
                            .frame(width: 55, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(effect.outTrans) },
                            set: { viewModel.updateSpotFadeOut(at: spotIndex, time: Float($0)) }
                        ), in: 0...30)
                        Text(String(format: "%.1fs", effect.outTrans))
                            .font(.caption.monospacedDigit())
                            .frame(width: 40)
                    }
                }
                
                // Loop toggle
                HStack {
                    Toggle(isOn: Binding(
                        get: { effect.loop },
                        set: { viewModel.updateSpotLoop(at: spotIndex, loop: $0) }
                    )) {
                        Label("Loop", systemImage: "repeat")
                            .font(.caption)
                    }
                    .toggleStyle(.checkbox)
                    
                    Spacer()
                    
                    // Play/Stop button
                    Button {
                        if effect.isPlaying() {
                            effect.stop()
                        } else {
                            effect.spotPlay()
                        }
                    } label: {
                        Label(effect.isPlaying() ? "Stop" : "Play", systemImage: effect.isPlaying() ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(effect.isPlaying() ? .red : .green)
                    .controlSize(.small)
                    
                    // Clear button
                    Button(role: .destructive) {
                        if spotIndex < 4 {
                            viewModel.clearSpotEffect(at: spotIndex)
                        } else {
                            viewModel.clearAnnouncement(at: spotIndex - 4)
                        }
                        viewModel.editingSpotIndex = nil
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(4)
        } label: {
            Label(isSpotEffect ? "Spot Effect Properties" : "Announcement Properties", systemImage: "slider.horizontal.3")
        }
        .padding(.horizontal)
    }
    
    private func panLabel(_ pan: Float) -> String {
        if abs(pan) < 0.05 { return "C" }
        if pan < 0 { return String(format: "L%.0f", abs(pan) * 100) }
        return String(format: "R%.0f", pan * 100)
    }
}

// MARK: - Spot Waveform Trim View

struct MacSpotWaveformTrimView: View {
    @ObservedObject var viewModel: MacMusicViewModel
    @State private var draggingHandle: TrimHandle? = nil
    
    private enum TrimHandle { case inPoint, outPoint }
    
    private let waveformHeight: CGFloat = 80
    private let rulerHeight: CGFloat = 18
    private let handleWidth: CGFloat = 16
    
    private var barCount: Int {
        min(Int(CGFloat(300) * viewModel.spotTrimZoomLevel), 3000)
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // Header with trim controls
            HStack(spacing: 6) {
                Text("WAVEFORM")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { viewModel.autoTrimSpotSilence() }) {
                    Label("Auto Trim", systemImage: "waveform.badge.minus")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .help("Auto-trim silence")
                
                Button(action: { viewModel.resetSpotTrimPoints() }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Reset trim to full file")
                
                Divider().frame(height: 10)
                
                // Zoom controls
                HStack(spacing: 3) {
                    Button(action: { viewModel.zoomOutSpotTrim() }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.spotTrimZoomLevel <= 1.0)
                    
                    Text("\(Int(viewModel.spotTrimZoomLevel * 100))%")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 32)
                    
                    Button(action: { viewModel.zoomInSpotTrim() }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.spotTrimZoomLevel >= 20.0)
                    
                    if viewModel.spotTrimZoomLevel > 1.0 {
                        Button(action: { viewModel.resetSpotTrimZoom() }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(.plain)
                        .help("Fit to Window")
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color(nsColor: .controlBackgroundColor)))
            }
            
            // Waveform
            GeometryReader { outerGeo in
                let viewportWidth = outerGeo.size.width
                let contentWidth = viewportWidth * viewModel.spotTrimZoomLevel
                
                AlwaysScrollableHorizontalView(
                    contentWidth: contentWidth,
                    contentHeight: waveformHeight + rulerHeight
                ) {
                    VStack(spacing: 0) {
                        // Time ruler
                        spotTimeRuler(contentWidth: contentWidth)
                            .frame(width: contentWidth, height: rulerHeight)
                        
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color(nsColor: .textBackgroundColor))
                                .allowsHitTesting(false)
                            
                            spotWaveformCanvas(contentWidth: contentWidth)
                            spotDimmedRegions(contentWidth: contentWidth)
                                .allowsHitTesting(false)
                            spotPlayhead(contentWidth: contentWidth)
                                .allowsHitTesting(false)
                            
                            // Click/drag to seek or move trim
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 1)
                                        .onChanged { value in
                                            guard viewModel.spotFileDuration > 0 else { return }
                                            let fraction = Float(value.location.x / contentWidth)
                                            let absTime = min(max(fraction, 0), 1) * viewModel.spotFileDuration
                                            if absTime < viewModel.spotInPoint {
                                                viewModel.updateSpotInPoint(absTime)
                                            } else if absTime > viewModel.spotOutPoint {
                                                viewModel.updateSpotOutPoint(absTime)
                                            }
                                        }
                                )
                                .onTapGesture { location in
                                    guard viewModel.spotFileDuration > 0 else { return }
                                    let fraction = Float(location.x / contentWidth)
                                    let absTime = min(max(fraction, 0), 1) * viewModel.spotFileDuration
                                    if absTime < viewModel.spotInPoint {
                                        viewModel.updateSpotInPoint(absTime)
                                    } else if absTime > viewModel.spotOutPoint {
                                        viewModel.updateSpotOutPoint(absTime)
                                    }
                                    viewModel.finishSpotTrimDrag()
                                }
                            
                            // Trim handles
                            if viewModel.spotFileDuration > 0 {
                                spotTrimHandle(
                                    label: "IN", color: .green,
                                    fraction: CGFloat(viewModel.spotInPoint / viewModel.spotFileDuration),
                                    contentWidth: contentWidth,
                                    handleType: .inPoint
                                )
                                
                                spotTrimHandle(
                                    label: "OUT", color: .orange,
                                    fraction: CGFloat(viewModel.spotOutPoint / viewModel.spotFileDuration),
                                    contentWidth: contentWidth,
                                    handleType: .outPoint
                                )
                            }
                        }
                        .frame(width: contentWidth, height: waveformHeight)
                        .coordinateSpace(name: "spotTrimWaveform")
                    }
                }
                .frame(height: waveformHeight + rulerHeight + (viewModel.spotTrimZoomLevel > 1 ? 15 : 0))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                )
            }
            .frame(height: waveformHeight + rulerHeight + (viewModel.spotTrimZoomLevel > 1 ? 15 : 0))
            
            // IN / OUT labels
            if viewModel.spotFileDuration > 0 {
                HStack {
                    HStack(spacing: 2) {
                        Image(systemName: "arrowtriangle.right.fill").font(.system(size: 5))
                        Text("IN \(formatDetailedTime(viewModel.spotInPoint))")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    }.foregroundColor(.green)
                    Spacer()
                    HStack(spacing: 2) {
                        Text("OUT \(formatDetailedTime(viewModel.spotOutPoint))")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        Image(systemName: "arrowtriangle.left.fill").font(.system(size: 5))
                    }.foregroundColor(.orange)
                }
                .padding(.horizontal, 2)
            }
        }
    }
    
    // MARK: - Trim Handle
    
    private func spotTrimHandle(label: String, color: Color, fraction: CGFloat, contentWidth: CGFloat, handleType: TrimHandle) -> some View {
        let x = contentWidth * fraction
        
        return ZStack {
            Rectangle()
                .fill(color)
                .frame(width: draggingHandle == handleType ? 3 : 2, height: waveformHeight)
                .shadow(color: color.opacity(0.6), radius: draggingHandle == handleType ? 4 : 2)
            
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    )
                
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 5))
                    .foregroundColor(color)
                    .offset(y: -2)
                
                Spacer()
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 12, height: 18)
                    .overlay(
                        VStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 0.5)
                                    .fill(Color.white.opacity(0.6))
                                    .frame(width: 5, height: 1)
                            }
                        }
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
            .frame(height: waveformHeight)
        }
        .frame(width: handleWidth, height: waveformHeight)
        .contentShape(Rectangle())
        .offset(x: x - handleWidth / 2)
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .named("spotTrimWaveform"))
                .onChanged { value in
                    draggingHandle = handleType
                    let newX = value.startLocation.x + value.translation.width
                    let newFrac = Float(max(0, min(newX / contentWidth, 1)))
                    let timePos = newFrac * viewModel.spotFileDuration
                    switch handleType {
                    case .inPoint:
                        viewModel.updateSpotInPoint(timePos)
                    case .outPoint:
                        viewModel.updateSpotOutPoint(timePos)
                    }
                }
                .onEnded { _ in
                    draggingHandle = nil
                    viewModel.finishSpotTrimDrag()
                }
        )
        .onHover { hovering in
            if hovering { NSCursor.resizeLeftRight.push() }
            else { NSCursor.pop() }
        }
    }
    
    // MARK: - Time Ruler
    
    private func spotTimeRuler(contentWidth: CGFloat) -> some View {
        Canvas { context, size in
            let duration = viewModel.spotFileDuration
            guard duration > 0 else { return }
            
            let pixelsPerSecond = size.width / CGFloat(duration)
            let tickInterval = rulerTickInterval(pixelsPerSecond: pixelsPerSecond)
            
            var time: Float = 0
            while time <= duration {
                let x = CGFloat(time / duration) * size.width
                
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: x, y: size.height))
                    p.addLine(to: CGPoint(x: x, y: size.height - 8))
                }, with: .color(.secondary.opacity(0.6)), lineWidth: 0.5)
                
                context.draw(
                    Text(formatDetailedTime(time))
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary),
                    at: CGPoint(x: x + 2, y: 5), anchor: .leading
                )
                
                time += tickInterval
                if tickInterval <= 0 { break }
            }
            
            context.stroke(Path { p in
                p.move(to: CGPoint(x: 0, y: size.height - 0.5))
                p.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
            }, with: .color(.secondary.opacity(0.3)), lineWidth: 0.5)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    private func rulerTickInterval(pixelsPerSecond: CGFloat) -> Float {
        for interval in [Float(0.1), 0.25, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300] {
            if pixelsPerSecond * CGFloat(interval) >= 60 { return interval }
        }
        return 300
    }
    
    // MARK: - Waveform Canvas
    
    private func spotWaveformCanvas(contentWidth: CGFloat) -> some View {
        let inFrac = viewModel.spotFileDuration > 0 ? Float(viewModel.spotInPoint / viewModel.spotFileDuration) : Float(0)
        let outFrac = viewModel.spotFileDuration > 0 ? Float(viewModel.spotOutPoint / viewModel.spotFileDuration) : Float(1)
        let n = barCount
        return Canvas { context, size in
            let barW = max(1.0, size.width / CGFloat(n) - 0.5)
            for i in 0..<n {
                let f = Float(i) / Float(n)
                let inTrim = f >= inFrac && f <= outFrac
                let h = barHeight(for: i, totalBars: n)
                let bh = size.height * h
                let rect = CGRect(x: CGFloat(i) * (barW + 0.5), y: (size.height - bh) / 2, width: barW, height: bh)
                context.fill(Path(roundedRect: rect, cornerRadius: 0.5),
                             with: .color(inTrim ? .accentColor.opacity(0.55) : .gray.opacity(0.15)))
            }
        }
        .frame(width: contentWidth, height: waveformHeight)
        .allowsHitTesting(false)
    }
    
    private func barHeight(for index: Int, totalBars: Int) -> CGFloat {
        let data = viewModel.spotTrimZoomLevel > 1.5 && !viewModel.spotHiResWaveformData.isEmpty
            ? viewModel.spotHiResWaveformData : viewModel.spotWaveformData
        if !data.isEmpty {
            let i = min(index * data.count / totalBars, data.count - 1)
            return max(0.03, min(0.95, 0.03 + CGFloat(data[i]) * 0.92))
        }
        return 0.03
    }
    
    // MARK: - Dimmed Regions
    
    private func spotDimmedRegions(contentWidth: CGFloat) -> some View {
        let inX = viewModel.spotFileDuration > 0 ? contentWidth * CGFloat(viewModel.spotInPoint / viewModel.spotFileDuration) : 0
        let outX = viewModel.spotFileDuration > 0 ? contentWidth * CGFloat(viewModel.spotOutPoint / viewModel.spotFileDuration) : contentWidth
        return ZStack(alignment: .leading) {
            if inX > 0 {
                Rectangle().fill(Color.black.opacity(0.35)).frame(width: inX, height: waveformHeight)
            }
            if outX < contentWidth {
                Rectangle().fill(Color.black.opacity(0.35)).frame(width: contentWidth - outX, height: waveformHeight).offset(x: outX)
            }
        }
    }
    
    // MARK: - Playhead
    
    private func spotPlayhead(contentWidth: CGFloat) -> some View {
        Group {
            if let idx = viewModel.editingSpotIndex, idx < fx.show.spotEffects.count,
               fx.show.spotEffects[idx].isPlaying(), viewModel.spotFileDuration > 0 {
                let pos = fx.show.spotEffects[idx].getPosition()
                let posX = contentWidth * CGFloat(min(max(pos / viewModel.spotFileDuration, 0), 1))
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 2)
                    .shadow(color: Color.green.opacity(0.6), radius: 2)
                    .offset(x: posX - 1)
            }
        }
    }
    
    private func formatDetailedTime(_ seconds: Float) -> String {
        let total = max(0, seconds)
        let mins = Int(total) / 60
        let secs = total - Float(mins * 60)
        return String(format: "%d:%05.2f", mins, secs)
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
    
    // Spot editing state
    @Published var editingSpotIndex: Int? = nil
    @Published var showingRenameAlert = false
    @Published var renameText = ""
    private var renamingSpotIndex: Int = 0
    
    // Waveform / Trim state for the currently-edited spot
    @Published var spotWaveformData: [Float] = []
    @Published var spotHiResWaveformData: [Float] = []
    @Published var spotFileDuration: Float = 0
    @Published var spotInPoint: Float = 0
    @Published var spotOutPoint: Float = 0
    @Published var spotTrimZoomLevel: CGFloat = 1.0
    @Published var spotCurrentPlaybackPosition: Float = 0
    
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
        panel.allowedContentTypes = [.audio, .mpeg4Audio, .mpeg4Movie, .mp3, .wav, .aiff]
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
    
    func deleteTrack(at index: Int) {
        guard index >= 0 && index < fx.show.music.count else { return }
        // Stop the track if it's currently playing
        if fx.show.music[index].isPlaying() {
            fx.show.music[index].stop()
        }
        fx.show.deleteMusic(index)
        // Adjust current track index
        if fx.show.music.isEmpty {
            fx.show.selectTrack(0)
        } else if index <= fx.show.currentTrackNo {
            fx.show.selectTrack(max(0, fx.show.currentTrackNo - 1))
        } else {
            fx.show.selectTrack(fx.show.currentTrackNo)
        }
        fx.show.save()
        loadPlaylist()
    }
    
    func deleteCurrentTrack() {
        guard currentTrackIndex >= 0 && currentTrackIndex < tracks.count else { return }
        deleteTrack(at: currentTrackIndex)
    }
    
    func moveTrackUp(from index: Int) {
        guard index > 0 && index < fx.show.music.count else { return }
        fx.show.reorderTracks(index, endNo: index - 1)
        // If the current track was involved, update selection
        if fx.show.currentTrackNo == index {
            fx.show.selectTrack(index - 1)
        } else if fx.show.currentTrackNo == index - 1 {
            fx.show.selectTrack(index)
        }
        fx.show.save()
        loadPlaylist()
    }
    
    func moveTrackDown(from index: Int) {
        guard index >= 0 && index < fx.show.music.count - 1 else { return }
        fx.show.reorderTracks(index, endNo: index + 1)
        // If the current track was involved, update selection
        if fx.show.currentTrackNo == index {
            fx.show.selectTrack(index + 1)
        } else if fx.show.currentTrackNo == index + 1 {
            fx.show.selectTrack(index)
        }
        fx.show.save()
        loadPlaylist()
    }
    
    func moveCurrentTrackUp() {
        guard currentTrackIndex > 0 else { return }
        moveTrackUp(from: currentTrackIndex)
    }
    
    func moveCurrentTrackDown() {
        guard currentTrackIndex < tracks.count - 1 else { return }
        moveTrackDown(from: currentTrackIndex)
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
        panel.allowedContentTypes = [.audio, .mpeg4Audio, .mpeg4Movie, .mp3, .wav, .aiff]
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
                // Fallback: use AVFoundation if BASS didn't return a valid duration
                if fx.show.spotEffects[index].outPoint <= 0 {
                    let asset = AVURLAsset(url: URL(fileURLWithPath: destPath))
                    let duration = Float(CMTimeGetSeconds(asset.duration))
                    if duration > 0 {
                        fx.show.spotEffects[index].outPoint = duration
                    }
                }
                fx.show.save()
                self?.updateSpotData()
                // Load waveform if this spot is being edited
                if self?.editingSpotIndex == index {
                    self?.loadSpotWaveformData(for: index)
                }
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
        panel.allowedContentTypes = [.audio, .mpeg4Audio, .mpeg4Movie, .mp3, .wav, .aiff]
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
                // Fallback: use AVFoundation if BASS didn't return a valid duration
                if fx.show.spotEffects[spotIdx].outPoint <= 0 {
                    let asset = AVURLAsset(url: URL(fileURLWithPath: destPath))
                    let duration = Float(CMTimeGetSeconds(asset.duration))
                    if duration > 0 {
                        fx.show.spotEffects[spotIdx].outPoint = duration
                    }
                }
                fx.show.save()
                self?.updateSpotData()
                // Load waveform if this spot is being edited
                if self?.editingSpotIndex == spotIdx {
                    self?.loadSpotWaveformData(for: spotIdx)
                }
            }
        }
    }
    
    // MARK: - Spot Effect Editing
    
    func editSpotEffect(at spotIndex: Int) {
        guard spotIndex < fx.show.spotEffects.count else { return }
        if editingSpotIndex == spotIndex {
            editingSpotIndex = nil
        } else {
            editingSpotIndex = spotIndex
            loadSpotWaveformData(for: spotIndex)
        }
    }
    
    func startRenaming(spotIndex: Int) {
        guard spotIndex < fx.show.spotEffects.count else { return }
        renamingSpotIndex = spotIndex
        renameText = fx.show.spotEffects[spotIndex].name
        showingRenameAlert = true
    }
    
    func confirmRename() {
        guard renamingSpotIndex < fx.show.spotEffects.count else { return }
        fx.show.spotEffects[renamingSpotIndex].name = renameText
        fx.show.save()
        updateSpotData()
    }
    
    func renameSpotEffect(at spotIndex: Int, name: String) {
        guard spotIndex < fx.show.spotEffects.count else { return }
        fx.show.spotEffects[spotIndex].name = name
        fx.show.save()
        updateSpotData()
    }
    
    func updateSpotLevel(at spotIndex: Int, level: Float) {
        guard spotIndex < fx.show.spotEffects.count else { return }
        fx.show.spotEffects[spotIndex].level = level
        // If currently playing, update live level
        if fx.show.spotEffects[spotIndex].isPlaying() {
            fx.audio.setLevel(fx.show.spotEffects[spotIndex].stream, level: level)
        }
        fx.show.save()
    }
    
    func updateSpotPan(at spotIndex: Int, pan: Float) {
        guard spotIndex < fx.show.spotEffects.count else { return }
        fx.show.spotEffects[spotIndex].pan = pan
        // If currently playing, update live pan
        if fx.show.spotEffects[spotIndex].isPlaying() {
            fx.audio.setPan(fx.show.spotEffects[spotIndex].stream, level: pan)
        }
        fx.show.save()
    }
    
    func updateSpotFadeIn(at spotIndex: Int, time: Float) {
        guard spotIndex < fx.show.spotEffects.count else { return }
        fx.show.spotEffects[spotIndex].inTrans = time
        fx.show.save()
    }
    
    func updateSpotFadeOut(at spotIndex: Int, time: Float) {
        guard spotIndex < fx.show.spotEffects.count else { return }
        fx.show.spotEffects[spotIndex].outTrans = time
        fx.show.save()
    }
    
    func updateSpotLoop(at spotIndex: Int, loop: Bool) {
        guard spotIndex < fx.show.spotEffects.count else { return }
        fx.show.spotEffects[spotIndex].loop = loop
        fx.show.save()
    }
    
    // MARK: - Spot Waveform & Trim
    
    func loadSpotWaveformData(for spotIndex: Int) {
        guard spotIndex < fx.show.spotEffects.count else { return }
        let effect = fx.show.spotEffects[spotIndex]
        guard !effect.file.isEmpty else {
            spotWaveformData = []
            spotHiResWaveformData = []
            spotFileDuration = 0
            return
        }
        let filePath = documentsPath(effect.file)
        
        // Load file duration
        fx.loadPreview(filePath)
        let dur = fx.getPreviewDurationSecs()
        if dur > 0 {
            spotFileDuration = dur
        } else {
            spotFileDuration = effect.outPoint > 0 ? effect.outPoint : 0
        }
        
        spotInPoint = effect.inPoint
        spotOutPoint = effect.outPoint
        spotCurrentPlaybackPosition = 0
        spotTrimZoomLevel = 1.0
        
        // Load waveform data on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let data = fx.getWaveformData(filePath: filePath, segments: 400)
            let hiRes = fx.getWaveformData(filePath: filePath, segments: 1600)
            DispatchQueue.main.async { [weak self] in
                self?.spotWaveformData = data
                self?.spotHiResWaveformData = hiRes
            }
        }
    }
    
    func updateSpotInPoint(_ newInPoint: Float) {
        guard let idx = editingSpotIndex, idx < fx.show.spotEffects.count else { return }
        let clamped = max(0, min(newInPoint, spotOutPoint - 0.1))
        spotInPoint = clamped
        fx.show.spotEffects[idx].inPoint = clamped
        fx.show.save()
    }
    
    func updateSpotOutPoint(_ newOutPoint: Float) {
        guard let idx = editingSpotIndex, idx < fx.show.spotEffects.count else { return }
        let clamped = min(spotFileDuration, max(newOutPoint, spotInPoint + 0.1))
        spotOutPoint = clamped
        fx.show.spotEffects[idx].outPoint = clamped
        fx.show.save()
    }
    
    func finishSpotTrimDrag() {
        objectWillChange.send()
    }
    
    func resetSpotTrimPoints() {
        guard let idx = editingSpotIndex, idx < fx.show.spotEffects.count, spotFileDuration > 0 else { return }
        spotInPoint = 0
        spotOutPoint = spotFileDuration
        fx.show.spotEffects[idx].inPoint = 0
        fx.show.spotEffects[idx].outPoint = spotFileDuration
        fx.show.save()
        objectWillChange.send()
    }
    
    func autoTrimSpotSilence() {
        guard let idx = editingSpotIndex, idx < fx.show.spotEffects.count, spotFileDuration > 0 else { return }
        let effect = fx.show.spotEffects[idx]
        let filePath = documentsPath(effect.file)
        
        var trimIn: Float = 0
        var trimOut: Float = 0
        fx.audio.getTrim(filePath, inPoint: &trimIn, outPont: &trimOut)
        
        if trimIn >= 0 && trimIn < spotFileDuration {
            spotInPoint = trimIn
            effect.inPoint = trimIn
        }
        if trimOut > spotInPoint && trimOut <= spotFileDuration {
            spotOutPoint = trimOut
            effect.outPoint = trimOut
        }
        fx.show.save()
        objectWillChange.send()
    }
    
    func zoomInSpotTrim() {
        spotTrimZoomLevel = min(spotTrimZoomLevel * 1.5, 20.0)
    }
    
    func zoomOutSpotTrim() {
        spotTrimZoomLevel = max(spotTrimZoomLevel / 1.5, 1.0)
    }
    
    func resetSpotTrimZoom() {
        spotTrimZoomLevel = 1.0
    }
    
    func formatDuration(_ seconds: Float) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
