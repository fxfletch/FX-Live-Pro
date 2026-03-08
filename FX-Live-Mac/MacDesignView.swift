//
//  MacDesignView.swift
//  FX-Live-Mac
//
//  Native macOS Design screen for cue and effect editing
//  Full-featured design view with audio timeline, waveform, scrubbing,
//  transport controls, and inline property editing
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main Design View

struct MacDesignView: View {
    @StateObject private var viewModel = MacDesignViewModel()
    
    var body: some View {
        HSplitView {
            // Left Panel: Cue List
            MacCueListPanel(viewModel: viewModel)
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
            
            // Center Panel: Effect List + Cue Properties
            MacEffectListPanel(viewModel: viewModel)
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 400)
            
            // Right Panel: Effect Editor with Timeline
            MacEffectEditorPanel(viewModel: viewModel)
                .frame(minWidth: 400, idealWidth: 500)
            
            // Far Right: Full-height Output Level Meters
            MacOutputMeterStrip(
                meterLeftDB: viewModel.meterLeftDB,
                meterRightDB: viewModel.meterRightDB,
                busLevels: [],
                multiOutputEnabled: false,
                busCount: 0
            )
            .frame(width: 50)
        }
        .padding(4)
        .onAppear {
            viewModel.loadShow()
        }
    }
}

// MARK: - Cue List Panel

struct MacCueListPanel: View {
    @ObservedObject var viewModel: MacDesignViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("CUES")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                
                Button(action: { viewModel.copyCue() }) {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy Cue")
                .disabled(viewModel.selectedCueIndex == nil)
                
                Button(action: { viewModel.pasteCue() }) {
                    Image(systemName: "doc.on.clipboard")
                }
                .help("Paste Cue")
                .disabled(!viewModel.canPaste)
                
                Button(action: { viewModel.addCue() }) {
                    Image(systemName: "plus")
                }
                .help("Add Cue")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Cue List
            if viewModel.cues.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "list.bullet")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No Cues")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Click + to add your first cue")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(Array(viewModel.cues.enumerated()), id: \.offset) { index, cue in
                    MacCueRow(cue: cue, index: index, isSelected: viewModel.selectedCueIndex == index)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectCue(at: index)
                        }
                        .listRowBackground(
                            viewModel.selectedCueIndex == index
                            ? Color.green.opacity(0.25)
                            : Color.clear
                        )
                        .contextMenu {
                            Button("Insert Cue Above") { viewModel.insertCue(at: index) }
                            Divider()
                            Button("Copy") { viewModel.selectCue(at: index); viewModel.copyCue() }
                            Button("Delete", role: .destructive) { viewModel.deleteCue(at: index) }
                        }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
            
            Divider()
            
            // Bottom toolbar
            HStack(spacing: 8) {
                Button(action: { viewModel.moveCueUp() }) {
                    Image(systemName: "arrow.up")
                }
                .disabled(viewModel.selectedCueIndex == nil || viewModel.selectedCueIndex == 0)
                .help("Move Cue Up")
                
                Button(action: { viewModel.moveCueDown() }) {
                    Image(systemName: "arrow.down")
                }
                .disabled(viewModel.selectedCueIndex == nil || viewModel.selectedCueIndex == (viewModel.cues.count - 1))
                .help("Move Cue Down")
                
                Spacer()
                
                Button("Renumber") { viewModel.renumberCues() }
                    .font(.caption)
                    .help("Renumber all cues sequentially")
                
                Button(action: { viewModel.deleteCueSelected() }) {
                    Image(systemName: "trash")
                }
                .disabled(viewModel.selectedCueIndex == nil)
                .help("Delete Cue")
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}

// MARK: - Cue Row

struct MacCueRow: View {
    let cue: FxCue
    let index: Int
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(cue.getName())
                    .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    Text("\(cue.totalEffects()) effects")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if cue.autoFollow {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 8))
                            Text("Auto")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.orange)
                    }
                    
                    if !cue.midi.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "music.note")
                                .font(.system(size: 8))
                            Text("MIDI")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            Text(formatSeconds(cue.duration()))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Effect List + Cue Properties Panel

struct MacEffectListPanel: View {
    @ObservedObject var viewModel: MacDesignViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            if let cueIndex = viewModel.selectedCueIndex, cueIndex < viewModel.cues.count {
                // Cue Properties (compact)
                MacCuePropertiesSection(viewModel: viewModel)
                
                Divider()
                
                // Effect List Header
                HStack {
                    Text("EFFECTS")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    
                    // Add Effect menu with types
                    Menu {
                        Button(action: { viewModel.addEffect(type: fx.TYPE_AUDIO) }) {
                            Label("Audio Effect", systemImage: "waveform")
                        }
                        Button(action: { viewModel.addEffect(type: fx.TYPE_MUSIC) }) {
                            Label("Music", systemImage: "music.note")
                        }
                        Button(action: { viewModel.addEffect(type: fx.TYPE_MIDI) }) {
                            Label("MIDI", systemImage: "music.note.list")
                        }
                        Divider()
                        Button(action: { viewModel.addEffect(type: fx.TYPE_IMAGE) }) {
                            Label("Image", systemImage: "photo")
                        }
                        Button(action: { viewModel.addEffect(type: fx.TYPE_VIDEO) }) {
                            Label("Video", systemImage: "video")
                        }
                        Button(action: { viewModel.addEffect(type: fx.TYPE_BLACK) }) {
                            Label("Black Screen", systemImage: "rectangle.fill")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 30)
                    .disabled(viewModel.selectedCueIndex == nil)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                
                Divider()
                
                // Effect List
                let cue = viewModel.cues[cueIndex]
                if cue.effects.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "waveform.badge.plus")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("No Effects")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Add an effect from the + menu")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(Array(cue.effects.enumerated()), id: \.offset) { index, effect in
                        MacEffectRow(effect: effect, isSelected: viewModel.selectedEffectIndex == index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectEffect(at: index)
                            }
                            .listRowBackground(
                                viewModel.selectedEffectIndex == index
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear
                            )
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    viewModel.deleteEffect(at: index)
                                }
                            }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
                
                Divider()
                
                // Effect list toolbar
                HStack(spacing: 8) {
                    Button(action: { viewModel.moveEffectUp() }) {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(viewModel.selectedEffectIndex == nil || viewModel.selectedEffectIndex == 0)
                    
                    Button(action: { viewModel.moveEffectDown() }) {
                        Image(systemName: "arrow.down")
                    }
                    .disabled(viewModel.selectedEffectIndex == nil)
                    
                    Spacer()
                    
                    Button(action: { viewModel.deleteEffectSelected() }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(viewModel.selectedEffectIndex == nil)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                
            } else {
                // No cue selected
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a cue to edit")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Cue Properties Section

struct MacCuePropertiesSection: View {
    @ObservedObject var viewModel: MacDesignViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cue Name
            HStack {
                Text("Cue:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
                TextField("Cue Name", text: $viewModel.cueName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .onSubmit { viewModel.saveCueProperties() }
            }
            
            // Notes
            VStack(alignment: .leading, spacing: 4) {
                Text("NOTES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                TextEditor(text: $viewModel.cueNotes)
                    .font(.system(size: 12))
                    .frame(minHeight: 80, maxHeight: 120)
                    .border(Color.gray.opacity(0.3), width: 1)
                    .onChange(of: viewModel.cueNotes) { _, _ in
                        viewModel.saveCueProperties()
                    }
            }
            
            // Auto-Follow
            HStack(spacing: 8) {
                Toggle("Auto-Follow", isOn: $viewModel.autoFollow)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .onChange(of: viewModel.autoFollow) { _, _ in viewModel.saveCueProperties() }
                
                if viewModel.autoFollow {
                    Picker("", selection: $viewModel.autoFollowEnd) {
                        Text("At End").tag(true)
                        Text("Timed").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                    .onChange(of: viewModel.autoFollowEnd) { _, _ in viewModel.saveCueProperties() }
                    
                    if !viewModel.autoFollowEnd {
                        TextField("", value: $viewModel.autoFollowDelay, format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .onSubmit { viewModel.saveCueProperties() }
                        Text("s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // MIDI
            HStack {
                Text("MIDI:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
                Text(viewModel.midiTrigger.isEmpty ? "No MIDI trigger" : viewModel.midiTrigger)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(viewModel.midiTrigger.isEmpty ? .secondary : .primary)
                Spacer()
                Button(viewModel.isMIDILearning ? "Listening…" : "Learn") {
                    viewModel.toggleMIDILearn()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(viewModel.isMIDILearning ? .red : .orange)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Effect Row

struct MacEffectRow: View {
    let effect: FxEffect
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            // Type icon
            Image(systemName: effectIcon)
                .font(.system(size: 16))
                .foregroundColor(effectColor)
                .frame(width: 22)
            
            // Effect info
            VStack(alignment: .leading, spacing: 2) {
                Text(effect.name)
                    .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(effect.type)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if effect.file.isEmpty && (effect.type == fx.TYPE_AUDIO || effect.type == fx.TYPE_MUSIC) {
                        Text("No file")
                            .font(.system(size: 10))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    
                    if effect.spotEffect {
                        Text("Spot")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    
                    if effect.background {
                        Text("BG")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.purple)
                    }
                    
                    if effect.loop {
                        Image(systemName: "repeat")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                    
                    if effect.output > 0 {
                        Text(OutputBus.labelFor(effect.output))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.cyan.opacity(0.2))
                            .cornerRadius(3)
                            .foregroundColor(.cyan)
                    }
                }
            }
            
            Spacer()
            
            // Level indicator
            if effect.type == fx.TYPE_AUDIO || effect.type == fx.TYPE_MUSIC {
                Text(String(format: "%.0f%%", effect.level * 100))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
    
    private var effectIcon: String {
        switch effect.type {
        case fx.TYPE_AUDIO: return "waveform"
        case fx.TYPE_MUSIC: return "music.note"
        case fx.TYPE_MIDI: return "music.note.list"
        case fx.TYPE_IMAGE: return "photo"
        case fx.TYPE_VIDEO: return "video"
        case fx.TYPE_BLACK: return "rectangle.fill"
        default: return "questionmark.circle"
        }
    }
    
    private var effectColor: Color {
        switch effect.type {
        case fx.TYPE_AUDIO: return .blue
        case fx.TYPE_MUSIC: return .purple
        case fx.TYPE_MIDI: return .orange
        case fx.TYPE_IMAGE: return .green
        case fx.TYPE_VIDEO: return .red
        case fx.TYPE_BLACK: return .gray
        default: return .secondary
        }
    }
}

// MARK: - Effect Editor Panel

struct MacEffectEditorPanel: View {
    @ObservedObject var viewModel: MacDesignViewModel
    
    var body: some View {
        if viewModel.selectedEffectIndex != nil, let effect = viewModel.currentEffect {
            ScrollView {
                VStack(spacing: 16) {
                    // Header: Effect name + Preview buttons
                    MacEffectHeaderSection(viewModel: viewModel, effect: effect)
                    
                    // File section
                    if effect.type == fx.TYPE_AUDIO || effect.type == fx.TYPE_MUSIC {
                        MacEffectFileSection(viewModel: viewModel)
                    }
                    
                    // Full-file waveform with trim handles (for audio/music)
                    if effect.type == fx.TYPE_AUDIO || effect.type == fx.TYPE_MUSIC {
                        MacFullWaveformTrimView(viewModel: viewModel)
                            .padding(.horizontal)
                        
                        // Trim controls (preview in/out, reset, set at playhead)
                        MacTrimControlsSection(viewModel: viewModel)
                    }
                    
                    // Trimmed region playback timeline (for audio/music)
                    if effect.type == fx.TYPE_AUDIO || effect.type == fx.TYPE_MUSIC {
                        MacAudioTimelineView(viewModel: viewModel)
                            .padding(.horizontal)
                        
                        // Transport controls (fades, delay, loop)
                        MacTransportSection(viewModel: viewModel)
                    }
                    
                    // Audio controls (level, pan)
                    if effect.type == fx.TYPE_AUDIO || effect.type == fx.TYPE_MUSIC {
                        MacAudioControlsSection(viewModel: viewModel)
                    }
                    
                    // Common controls (delay, spot, background)
                    MacCommonControlsSection(viewModel: viewModel, effect: effect)
                }
                .padding()
            }
        } else {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Select an effect to edit")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text("Choose an effect from the list to view its properties and timeline")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Effect Header Section

struct MacEffectHeaderSection: View {
    @ObservedObject var viewModel: MacDesignViewModel
    let effect: FxEffect
    
    var body: some View {
        HStack(spacing: 12) {
            // Effect type icon
            Image(systemName: iconForType(effect.type))
                .font(.system(size: 24))
                .foregroundColor(colorForType(effect.type))
                .frame(width: 32)
            
            // Effect Name
            VStack(alignment: .leading, spacing: 2) {
                Text("EFFECT")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("Effect Name", text: $viewModel.effectName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
                    .onSubmit { viewModel.saveEffectProperties() }
            }
            
            Spacer()
            
            // Preview buttons
            HStack(spacing: 8) {
                Button(action: { viewModel.togglePreviewEffect() }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isPreviewingEffect ? "stop.fill" : "play.fill")
                            .font(.system(size: 11))
                        Text("Effect")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(viewModel.isPreviewingEffect ? Color.red : Color.blue)
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: { viewModel.togglePreviewCue() }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isPreviewingCue ? "stop.fill" : "play.fill")
                            .font(.system(size: 11))
                        Text("Cue")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(viewModel.isPreviewingCue ? Color.red : Color.green)
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case fx.TYPE_AUDIO: return "waveform"
        case fx.TYPE_MUSIC: return "music.note"
        case fx.TYPE_MIDI: return "music.note.list"
        case fx.TYPE_IMAGE: return "photo"
        case fx.TYPE_VIDEO: return "video"
        case fx.TYPE_BLACK: return "rectangle.fill"
        default: return "questionmark"
        }
    }
    
    private func colorForType(_ type: String) -> Color {
        switch type {
        case fx.TYPE_AUDIO: return .blue
        case fx.TYPE_MUSIC: return .purple
        case fx.TYPE_MIDI: return .orange
        case fx.TYPE_IMAGE: return .green
        case fx.TYPE_VIDEO: return .red
        case fx.TYPE_BLACK: return .gray
        default: return .secondary
        }
    }
}

// MARK: - File Section

struct MacEffectFileSection: View {
    @ObservedObject var viewModel: MacDesignViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            Text("FILE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .trailing)
            
            Text(viewModel.effectFile.isEmpty ? "No file selected" : viewModel.effectFile)
                .font(.system(size: 13))
                .foregroundColor(viewModel.effectFile.isEmpty ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
            
            Button("Browse…") {
                viewModel.browseForFile()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }
}

// MARK: - Full Waveform Trim View

/// Shows the complete audio file waveform with draggable in/out trim handles,
/// dimmed regions outside the trim, and playhead position indicator
struct MacFullWaveformTrimView: View {
    @ObservedObject var viewModel: MacDesignViewModel
    @State private var draggingHandle: TrimHandle? = nil
    
    private enum TrimHandle { case inPoint, outPoint }
    
    private let timelineHeight: CGFloat = 80
    private let barCount: Int = 200
    private let handleHitArea: CGFloat = 24
    
    var body: some View {
        VStack(spacing: 4) {
            // Header
            HStack {
                Text("FULL FILE WAVEFORM")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                
                if viewModel.fileDuration > 0 && viewModel.effectDuration > 0 {
                    // Trimmed duration badge
                    Text("Trimmed: \(formatDetailedTime(viewModel.effectDuration))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor.opacity(0.6)))
                }
                
                Spacer()
                
                if viewModel.fileDuration > 0 {
                    Text("File: \(formatDetailedTime(viewModel.fileDuration))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            // Waveform with trim handles
            GeometryReader { geometry in
                let w = geometry.size.width
                let inFrac = viewModel.fileDuration > 0 ? CGFloat(viewModel.inPoint / viewModel.fileDuration) : 0
                let outFrac = viewModel.fileDuration > 0 ? CGFloat(viewModel.outPoint / viewModel.fileDuration) : 1
                let inX = w * inFrac
                let outX = w * outFrac
                
                // Base waveform layer (clipped to rounded rect)
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .textBackgroundColor))
                    
                    // Full waveform bars
                    fullWaveformBars(in: geometry, inFrac: Float(inFrac), outFrac: Float(outFrac))
                    
                    // Dimmed region before in point
                    if viewModel.fileDuration > 0 && inX > 0 {
                        Rectangle()
                            .fill(Color.black.opacity(0.35))
                            .frame(width: max(0, inX), height: timelineHeight)
                    }
                    
                    // Dimmed region after out point
                    if viewModel.fileDuration > 0 && outX < w {
                        Rectangle()
                            .fill(Color.black.opacity(0.35))
                            .frame(width: max(0, w - outX), height: timelineHeight)
                            .offset(x: outX)
                    }
                    
                    // Playhead position (mapped to full file)
                    if viewModel.fileDuration > 0 && viewModel.effectDuration > 0 {
                        let absolutePos = viewModel.inPoint + viewModel.currentPlaybackPosition
                        let posFrac = CGFloat(absolutePos / viewModel.fileDuration)
                        let posX = w * min(max(posFrac, 0), 1)
                        
                        Rectangle()
                            .fill(viewModel.isPreviewingEffect ? Color.green : Color.white)
                            .frame(width: 1.5)
                            .shadow(color: (viewModel.isPreviewingEffect ? Color.green : Color.white).opacity(0.6), radius: 2)
                            .offset(x: posX - 0.75)
                    }
                    
                    // No audio message
                    if viewModel.fileDuration <= 0 {
                        Text("No audio loaded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: timelineHeight)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                // Trim handle markers — rendered OUTSIDE the clip so they're always visible
                .overlay(
                    ZStack(alignment: .leading) {
                        if viewModel.fileDuration > 0 {
                            // In point marker
                            trimMarker(label: "IN", color: .green, x: inX, isActive: draggingHandle == .inPoint)
                            
                            // Out point marker
                            trimMarker(label: "OUT", color: .orange, x: outX, isActive: draggingHandle == .outPoint)
                        }
                    }
                    .frame(height: timelineHeight)
                    , alignment: .leading
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            draggingHandle != nil ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.3),
                            lineWidth: draggingHandle != nil ? 1.5 : 0.5
                        )
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard viewModel.fileDuration > 0 else { return }
                            let x = value.location.x
                            let startX = value.startLocation.x
                            
                            // On first touch, decide what to drag
                            if draggingHandle == nil {
                                let inHandleX = w * CGFloat(viewModel.inPoint / viewModel.fileDuration)
                                let outHandleX = w * CGFloat(viewModel.outPoint / viewModel.fileDuration)
                                
                                let distToIn = abs(startX - inHandleX)
                                let distToOut = abs(startX - outHandleX)
                                
                                if distToIn < handleHitArea && distToOut < handleHitArea {
                                    draggingHandle = distToIn <= distToOut ? .inPoint : .outPoint
                                } else if distToIn < handleHitArea {
                                    draggingHandle = .inPoint
                                } else if distToOut < handleHitArea {
                                    draggingHandle = .outPoint
                                }
                            }
                            
                            let fraction = Float(x / w)
                            let clampedFraction = min(max(fraction, 0), 1)
                            let timePos = clampedFraction * viewModel.fileDuration
                            
                            switch draggingHandle {
                            case .inPoint:
                                viewModel.updateInPointAbsolute(timePos)
                            case .outPoint:
                                viewModel.updateOutPointAbsolute(timePos)
                            case nil:
                                break
                            }
                        }
                        .onEnded { _ in
                            if draggingHandle != nil {
                                viewModel.finishTrimDrag()
                            }
                            draggingHandle = nil
                        }
                )
            }
            .frame(height: timelineHeight)
            
            // Time labels — positioned to track the markers
            if viewModel.fileDuration > 0 {
                HStack {
                    Text(formatDetailedTime(0))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 3) {
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.system(size: 6))
                        Text("IN \(formatDetailedTime(viewModel.inPoint))")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(.green)
                    
                    Spacer()
                    
                    HStack(spacing: 3) {
                        Text("OUT \(formatDetailedTime(viewModel.outPoint))")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        Image(systemName: "arrowtriangle.left.fill")
                            .font(.system(size: 6))
                    }
                    .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Text(formatDetailedTime(viewModel.fileDuration))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Trim Marker
    
    private func trimMarker(label: String, color: Color, x: CGFloat, isActive: Bool) -> some View {
        ZStack {
            // Vertical line — full height
            Rectangle()
                .fill(color)
                .frame(width: isActive ? 3 : 2, height: timelineHeight)
                .shadow(color: color.opacity(0.6), radius: isActive ? 4 : 2)
            
            // Label tab at top
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .shadow(color: Color.black.opacity(0.4), radius: 2, y: 1)
                    )
                
                // Arrow pointing down to the line
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 6))
                    .foregroundColor(color)
                    .offset(y: -2)
                
                Spacer()
                
                // Bottom grip handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 10, height: 18)
                    .overlay(
                        VStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 0.5)
                                    .fill(Color.white.opacity(0.6))
                                    .frame(width: 5, height: 1)
                            }
                        }
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 2)
            }
            .frame(height: timelineHeight)
        }
        .offset(x: x - 1)
    }
    
    // MARK: - Full Waveform Bars
    
    private func fullWaveformBars(in geometry: GeometryProxy, inFrac: Float, outFrac: Float) -> some View {
        HStack(spacing: 0.5) {
            ForEach(0..<barCount, id: \.self) { index in
                let height = barHeight(for: index)
                let barFrac = Float(index) / Float(barCount)
                let isInTrimRegion = barFrac >= inFrac && barFrac <= outFrac
                
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(isInTrimRegion ? Color.accentColor.opacity(0.55) : Color.gray.opacity(0.15))
                    .frame(height: timelineHeight * height)
            }
        }
        .frame(height: timelineHeight)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        if !viewModel.fullWaveformData.isEmpty {
            let dataIndex = index * viewModel.fullWaveformData.count / barCount
            let clampedIndex = min(dataIndex, viewModel.fullWaveformData.count - 1)
            let peak = CGFloat(viewModel.fullWaveformData[clampedIndex])
            return max(0.03, min(0.95, 0.03 + peak * 0.92))
        }
        // Fallback
        let n = Double(index) / Double(barCount)
        let base = 0.15 + (sin(n * .pi * 6) * 0.3 + sin(n * .pi * 13) * 0.15 + 0.5) * sin(n * .pi) * 0.5
        return max(0.03, min(0.95, CGFloat(base)))
    }
    
    private func formatDetailedTime(_ seconds: Float) -> String {
        let total = max(0, seconds)
        let mins = Int(total) / 60
        let secs = total - Float(mins * 60)
        return String(format: "%d:%05.2f", mins, secs)
    }
}

// MARK: - Trim Controls Section

struct MacTrimControlsSection: View {
    @ObservedObject var viewModel: MacDesignViewModel
    
    var body: some View {
        GroupBox("Trim") {
            HStack(spacing: 16) {
                // In point controls
                VStack(alignment: .leading, spacing: 4) {
                    Text("In Point")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.green)
                    
                    HStack(spacing: 6) {
                        // In point value
                        TextField("", value: $viewModel.inPoint, format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 65)
                            .font(.system(size: 12, design: .monospaced))
                            .onSubmit { viewModel.saveEffectProperties() }
                        Text("s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Set at playhead
                        Button(action: { viewModel.setInPointAtPlayhead() }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                        }
                        .help("Set in point at playhead")
                        .buttonStyle(.bordered)
                        
                        // Preview in
                        Button(action: { viewModel.sampleInPoint() }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 12))
                        }
                        .help("Preview in point")
                        .buttonStyle(.bordered)
                        .tint(.green)
                    }
                }
                
                Spacer()
                
                // Reset button
                VStack(spacing: 4) {
                    Text(" ")
                        .font(.system(size: 10, weight: .semibold))
                    
                    Button(action: { viewModel.resetTrimPoints() }) {
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14))
                            Text("Reset")
                                .font(.system(size: 9))
                        }
                    }
                    .help("Reset to full file")
                    .buttonStyle(.bordered)
                    .disabled(viewModel.fileDuration <= 0)
                }
                
                Spacer()
                
                // Out point controls
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Out Point")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    HStack(spacing: 6) {
                        // Preview out
                        Button(action: { viewModel.sampleOutPoint() }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 12))
                        }
                        .help("Preview out point")
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        
                        // Set at playhead
                        Button(action: { viewModel.setOutPointAtPlayhead() }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                        }
                        .help("Set out point at playhead")
                        .buttonStyle(.bordered)
                        
                        // Out point value
                        TextField("", value: $viewModel.outPoint, format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 65)
                            .font(.system(size: 12, design: .monospaced))
                            .onSubmit { viewModel.saveEffectProperties() }
                        Text("s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
        }
        .padding(.horizontal)
    }
}

// MARK: - Audio Timeline View (Mac) - Trimmed Region Playback

struct MacAudioTimelineView: View {
    @ObservedObject var viewModel: MacDesignViewModel
    
    private let timelineHeight: CGFloat = 80
    private let barCount: Int = 200
    
    var body: some View {
        VStack(spacing: 6) {
            // Timeline label row
            HStack {
                Text("PLAYBACK TIMELINE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                
                // Duration badge
                if viewModel.effectDuration > 0 {
                    Text(formatTimeValue(viewModel.effectDuration))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.5)))
                }
                
                if viewModel.effectLoop {
                    HStack(spacing: 3) {
                        Image(systemName: "repeat")
                            .font(.system(size: 9))
                        Text("LOOP")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange))
                }
                
                Spacer()
                
                // Go to In
                Button(action: { viewModel.goToInPoint() }) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.green)
                .help("Go to In point")
                .disabled(viewModel.effectDuration <= 0)
                
                // Play/pause from current position
                Button(action: { viewModel.togglePlayFromPosition() }) {
                    Image(systemName: viewModel.isPreviewingEffect ? "pause.fill" : "play.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(viewModel.isPreviewingEffect ? Color.red : Color.green)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.effectDuration <= 0)
                .opacity(viewModel.effectDuration <= 0 ? 0.4 : 1.0)
                
                // Go to Out
                Button(action: { viewModel.goToOutPoint() }) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.orange)
                .help("Go to Out point")
                .disabled(viewModel.effectDuration <= 0)
                
                // Time display
                Text(timeDisplay)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(viewModel.isPreviewingEffect ? .green : .secondary)
            }
            
            // Timeline visualization
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .textBackgroundColor))
                    
                    // Waveform bars
                    waveformBars(in: geometry)
                    
                    // Fade-in overlay
                    if viewModel.effectDuration > 0 && viewModel.fadeIn > 0 {
                        fadeInOverlay(in: geometry)
                    }
                    
                    // Fade-out overlay
                    if viewModel.effectDuration > 0 && viewModel.fadeOut > 0 {
                        fadeOutOverlay(in: geometry)
                    }
                    
                    // Progress fill
                    if viewModel.effectDuration > 0 {
                        let progress = CGFloat(viewModel.currentPlaybackPosition / viewModel.effectDuration)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.05)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * min(max(progress, 0), 1))
                    }
                    
                    // Playhead
                    if viewModel.effectDuration > 0 {
                        let progress = CGFloat(viewModel.currentPlaybackPosition / viewModel.effectDuration)
                        let clampedProgress = min(max(progress, 0), 1)
                        
                        Rectangle()
                            .fill(viewModel.isPreviewingEffect ? Color.green : Color.blue)
                            .frame(width: 2)
                            .shadow(color: (viewModel.isPreviewingEffect ? Color.green : Color.blue).opacity(0.5), radius: 2)
                            .offset(x: geometry.size.width * clampedProgress - 1)
                        
                        // Playhead handle
                        Circle()
                            .fill(viewModel.isPreviewingEffect ? Color.green : Color.blue)
                            .frame(width: 10, height: 10)
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                            .offset(x: geometry.size.width * clampedProgress - 5,
                                    y: -timelineHeight / 2 + 2)
                    }
                    
                    // No audio message
                    if viewModel.effectDuration <= 0 {
                        Text("No audio loaded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: timelineHeight)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            viewModel.isDraggingTimeline
                            ? (viewModel.isPreviewingEffect ? Color.green : Color.blue)
                            : Color.gray.opacity(0.3),
                            lineWidth: viewModel.isDraggingTimeline ? 1.5 : 0.5
                        )
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            viewModel.isDraggingTimeline = true
                            let fraction = Float(value.location.x / geometry.size.width)
                            let clampedFraction = min(max(fraction, 0), 1)
                            let newPosition = clampedFraction * viewModel.effectDuration
                            viewModel.seekToPosition(newPosition)
                        }
                        .onEnded { _ in
                            viewModel.isDraggingTimeline = false
                        }
                )
            }
            .frame(height: timelineHeight)
            
            // Time markers row
            if viewModel.effectDuration > 0 {
                timeMarkersRow
            }
        }
    }
    
    // MARK: - Fade Overlays
    
    private func fadeInOverlay(in geometry: GeometryProxy) -> some View {
        let fadeFraction = CGFloat(viewModel.fadeIn / viewModel.effectDuration)
        let fadeWidth = geometry.size.width * min(fadeFraction, 1)
        
        return ZStack(alignment: .leading) {
            LinearGradient(
                colors: [Color.green.opacity(0.25), Color.green.opacity(0.0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: fadeWidth, height: timelineHeight)
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: timelineHeight))
                path.addLine(to: CGPoint(x: fadeWidth, y: timelineHeight * 0.2))
            }
            .stroke(Color.green.opacity(0.6), lineWidth: 1.5)
            .frame(width: fadeWidth, height: timelineHeight)
        }
    }
    
    private func fadeOutOverlay(in geometry: GeometryProxy) -> some View {
        let fadeFraction = CGFloat(viewModel.fadeOut / viewModel.effectDuration)
        let fadeWidth = geometry.size.width * min(fadeFraction, 1)
        let fadeStartX = geometry.size.width - fadeWidth
        
        return ZStack(alignment: .trailing) {
            LinearGradient(
                colors: [Color.red.opacity(0.0), Color.red.opacity(0.25)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: fadeWidth, height: timelineHeight)
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: timelineHeight * 0.2))
                path.addLine(to: CGPoint(x: fadeWidth, y: timelineHeight))
            }
            .stroke(Color.red.opacity(0.6), lineWidth: 1.5)
            .frame(width: fadeWidth, height: timelineHeight)
        }
        .offset(x: fadeStartX)
    }
    
    // MARK: - Time Markers
    
    private var timeMarkersRow: some View {
        HStack {
            Text(formatTimeValue(0))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
            
            Spacer()
            
            if viewModel.fadeIn > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8))
                    Text(formatTimeValue(viewModel.fadeIn))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.green.opacity(0.8))
            }
            
            Spacer()
            
            if viewModel.fadeOut > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down.right")
                        .font(.system(size: 8))
                    Text(formatTimeValue(viewModel.fadeOut))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.red.opacity(0.8))
            }
            
            Spacer()
            
            Text(formatTimeValue(viewModel.effectDuration))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Waveform Bars
    
    private func waveformBars(in geometry: GeometryProxy) -> some View {
        HStack(spacing: 0.5) {
            ForEach(0..<barCount, id: \.self) { index in
                let height = waveformBarHeight(for: index, totalBars: barCount)
                let isPlayed = viewModel.effectDuration > 0 &&
                    Float(index) / Float(barCount) < (viewModel.currentPlaybackPosition / viewModel.effectDuration)
                
                let barFraction = Float(index) / Float(barCount)
                let inFadeRegion = viewModel.fadeIn > 0 &&
                    viewModel.effectDuration > 0 &&
                    barFraction < (viewModel.fadeIn / viewModel.effectDuration)
                let outFadeRegion = viewModel.fadeOut > 0 &&
                    viewModel.effectDuration > 0 &&
                    barFraction > (1.0 - viewModel.fadeOut / viewModel.effectDuration)
                
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(barColor(isPlayed: isPlayed, inFade: inFadeRegion, outFade: outFadeRegion))
                    .frame(height: timelineHeight * height)
            }
        }
        .frame(height: timelineHeight)
    }
    
    private func barColor(isPlayed: Bool, inFade: Bool, outFade: Bool) -> Color {
        if isPlayed {
            if inFade { return Color.green.opacity(0.6) }
            if outFade { return Color.red.opacity(0.6) }
            return viewModel.isPreviewingEffect ? Color.green.opacity(0.6) : Color.blue.opacity(0.6)
        } else {
            if inFade { return Color.green.opacity(0.2) }
            if outFade { return Color.red.opacity(0.2) }
            return Color.gray.opacity(0.3)
        }
    }
    
    private func waveformBarHeight(for index: Int, totalBars: Int) -> CGFloat {
        if !viewModel.waveformData.isEmpty {
            let dataIndex = index * viewModel.waveformData.count / totalBars
            let clampedIndex = min(dataIndex, viewModel.waveformData.count - 1)
            let peak = CGFloat(viewModel.waveformData[clampedIndex])
            return max(0.05, min(0.95, 0.05 + peak * 0.90))
        }
        
        // Fallback: simulated waveform
        let n = Double(index) / Double(totalBars)
        let wave1 = sin(n * .pi * 6.0) * 0.3
        let wave2 = sin(n * .pi * 13.0) * 0.15
        let wave3 = sin(n * .pi * 21.0) * 0.1
        let envelope = sin(n * .pi)
        let base = 0.15 + (wave1 + wave2 + wave3 + 0.5) * envelope * 0.5
        return max(0.05, min(0.95, CGFloat(base)))
    }
    
    // MARK: - Time Display
    
    private var timeDisplay: String {
        let position = viewModel.currentPlaybackPosition
        let duration = viewModel.effectDuration
        if duration <= 0 { return "--:-- / --:--" }
        return "\(formatTimeValue(position)) / \(formatTimeValue(duration))"
    }
    
    private func formatTimeValue(_ seconds: Float) -> String {
        let total = max(0, seconds)
        let mins = Int(total) / 60
        let secs = total - Float(mins * 60)
        return String(format: "%d:%05.2f", mins, secs)
    }
}

// MARK: - Transport Section (In/Out, Fades, Loop)

struct MacTransportSection: View {
    @ObservedObject var viewModel: MacDesignViewModel
    
    var body: some View {
        GroupBox("Fades & Timing") {
            VStack(spacing: 10) {
                // Fade In/Out
                HStack(spacing: 16) {
                    HStack {
                        Text("Fade In:")
                            .font(.caption)
                            .foregroundColor(.green)
                            .frame(width: 55, alignment: .trailing)
                        TextField("", value: $viewModel.fadeIn, format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .onSubmit { viewModel.saveEffectProperties() }
                        Text("s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Fade Out:")
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(width: 60, alignment: .trailing)
                        TextField("", value: $viewModel.fadeOut, format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .onSubmit { viewModel.saveEffectProperties() }
                        Text("s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Delay + Loop row
                HStack(spacing: 16) {
                    HStack {
                        Text("Delay:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 55, alignment: .trailing)
                        TextField("", value: $viewModel.effectDelay, format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .onSubmit { viewModel.saveEffectProperties() }
                        Text("s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle(isOn: $viewModel.effectLoop) {
                        HStack(spacing: 4) {
                            Image(systemName: "repeat")
                                .font(.caption)
                                .foregroundColor(viewModel.effectLoop ? .orange : .secondary)
                            Text("Loop")
                                .font(.caption)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .onChange(of: viewModel.effectLoop) { _, _ in viewModel.saveEffectProperties() }
                    
                    Spacer()
                }
            }
            .padding(8)
        }
        .padding(.horizontal)
    }
}

// MARK: - Audio Controls Section

struct MacAudioControlsSection: View {
    @ObservedObject var viewModel: MacDesignViewModel
    
    var body: some View {
        GroupBox("Level & Pan") {
            VStack(spacing: 10) {
                // Level
                HStack {
                    Text("Level:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                    Slider(value: $viewModel.effectLevel, in: 0...2)
                        .onChange(of: viewModel.effectLevel) { _, _ in viewModel.saveEffectProperties() }
                    Text(levelLabel)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(viewModel.effectLevel > 1.0 ? .orange : .primary)
                        .frame(width: 60)
                }
                
                // Pan
                HStack {
                    Text("Pan:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                    Slider(value: $viewModel.effectPan, in: -1...1)
                        .onChange(of: viewModel.effectPan) { _, _ in viewModel.saveEffectProperties() }
                    Text(panLabel)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(width: 60)
                }
            }
            .padding(8)
        }
        .padding(.horizontal)
    }
    
    private var levelLabel: String {
        let level = viewModel.effectLevel
        if level <= 0 { return "-∞ dB" }
        let dB = 20 * log10(level)
        if abs(dB) < 0.01 { return "0.00 dB" }
        return String(format: "%+.2f dB", dB)
    }
    
    private var panLabel: String {
        if viewModel.effectPan == 0 { return "Center" }
        if viewModel.effectPan < 0 { return "L\(Int(abs(viewModel.effectPan) * 100))%" }
        return "R\(Int(viewModel.effectPan * 100))%"
    }
}

// MARK: - Common Controls Section

struct MacCommonControlsSection: View {
    @ObservedObject var viewModel: MacDesignViewModel
    let effect: FxEffect
    
    var body: some View {
        GroupBox("Options") {
            VStack(spacing: 8) {
                // Output selector
                HStack {
                    Text("Output:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .trailing)
                    
                    let busCount = MacOutputManager.shared.buses.count
                    
                    if busCount <= 8 {
                        // Segmented style for small number of buses
                        Picker("", selection: $viewModel.effectOutput) {
                            ForEach(0..<busCount, id: \.self) { i in
                                Text(OutputBus.labelFor(i)).tag(i)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: CGFloat(busCount) * 40)
                        .onChange(of: viewModel.effectOutput) { _, _ in viewModel.saveEffectProperties() }
                    } else {
                        // Dropdown for many buses
                        Picker("", selection: $viewModel.effectOutput) {
                            ForEach(0..<busCount, id: \.self) { i in
                                Text("Output \(OutputBus.labelFor(i))").tag(i)
                            }
                        }
                        .frame(width: 140)
                        .onChange(of: viewModel.effectOutput) { _, _ in viewModel.saveEffectProperties() }
                    }
                    
                    Spacer()
                }
                
                // Delay (for non-audio types that don't show transport)
                if effect.type != fx.TYPE_AUDIO && effect.type != fx.TYPE_MUSIC {
                    HStack {
                        Text("Delay:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .trailing)
                        TextField("", value: $viewModel.effectDelay, format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .onSubmit { viewModel.saveEffectProperties() }
                        Text("s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                
                HStack(spacing: 20) {
                    Toggle("Spot Effect", isOn: $viewModel.isSpotEffect)
                        .toggleStyle(.checkbox)
                        .onChange(of: viewModel.isSpotEffect) { _, _ in viewModel.saveEffectProperties() }
                    
                    Toggle("Background (continues after GO)", isOn: $viewModel.effectBackground)
                        .toggleStyle(.checkbox)
                        .onChange(of: viewModel.effectBackground) { _, _ in viewModel.saveEffectProperties() }
                    
                    Toggle("Don't Fade", isOn: $viewModel.effectDontFade)
                        .toggleStyle(.checkbox)
                        .onChange(of: viewModel.effectDontFade) { _, _ in viewModel.saveEffectProperties() }
                    
                    Spacer()
                }
            }
            .padding(8)
        }
        .padding(.horizontal)
    }
}

// MARK: - View Model

@MainActor
class MacDesignViewModel: ObservableObject {
    // MARK: - Published State
    
    // Cue list
    @Published var cues: [FxCue] = []
    @Published var selectedCueIndex: Int?
    @Published var selectedEffectIndex: Int?
    
    // Cue properties
    @Published var cueName = ""
    @Published var cueNotes = ""
    @Published var autoFollow = false
    @Published var autoFollowDelay: Float = 0
    @Published var autoFollowEnd = true
    @Published var midiTrigger = ""
    @Published var isMIDILearning = false
    
    // Effect properties
    @Published var effectName = ""
    @Published var effectFile = ""
    @Published var effectLevel: Float = 1.0
    @Published var effectPan: Float = 0
    @Published var fadeIn: Float = 0
    @Published var fadeOut: Float = 0
    @Published var effectDelay: Float = 0
    @Published var inPoint: Float = 0
    @Published var outPoint: Float = 0
    @Published var effectLoop = false
    @Published var effectBackground = false
    @Published var isSpotEffect = false
    @Published var effectOutput: Int = 0
    @Published var effectDontFade = false
    
    // Timeline/playback state
    @Published var currentPlaybackPosition: Float = 0
    @Published var effectDuration: Float = 0
    @Published var fileDuration: Float = 0  // Full file duration (before trim)
    @Published var isDraggingTimeline = false
    @Published var waveformData: [Float] = []
    @Published var fullWaveformData: [Float] = []  // Full file waveform for trim view
    @Published var isPreviewingEffect = false
    @Published var isPreviewingCue = false
    
    // Output meters
    @Published var meterLeftDB: Float = -100
    @Published var meterRightDB: Float = -100
    
    // Clipboard
    @Published var canPaste = false
    private var copiedCueData: Data?
    
    // Timer for updates
    private var updateTimer: Timer?
    
    // MARK: - Computed Properties
    
    var currentEffect: FxEffect? {
        guard let cueIndex = selectedCueIndex, cueIndex < cues.count,
              let effectIndex = selectedEffectIndex else { return nil }
        let cue = cues[cueIndex]
        guard effectIndex < cue.effects.count else { return nil }
        return cue.effects[effectIndex]
    }
    
    // MARK: - Initialization
    
    init() {
        startUpdateTimer()
        setupNotifications()
    }
    
    deinit {
        updateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Load Data
    
    func loadShow() {
        cues = fx.show.currentVersion.cues
        
        // Re-select if we had a selection
        if let idx = selectedCueIndex, idx < cues.count {
            selectCue(at: idx)
        }
    }
    
    // MARK: - Update Timer
    
    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updatePlaybackState()
            }
        }
    }
    
    private func updatePlaybackState() {
        // Poll mixer output levels for meters
        let levels = fx.getMixerLevels()
        meterLeftDB = levels.left
        meterRightDB = levels.right
        
        guard let effect = currentEffect else { return }
        
        let wasPlaying = isPreviewingEffect
        isPreviewingEffect = effect.isPlaying()
        
        // Track playback position
        if effect.type == fx.TYPE_AUDIO || effect.type == fx.TYPE_MUSIC {
            let duration = effect.getDuration()
            if duration > 0 {
                effectDuration = duration
            }
            
            if effect.isPlaying() && !isDraggingTimeline {
                currentPlaybackPosition = effect.getPosition()
            }
            
            if wasPlaying && !isPreviewingEffect && !isDraggingTimeline {
                currentPlaybackPosition = 0
            }
        }
        
        // Check cue playing state
        if let cueIndex = selectedCueIndex, cueIndex < cues.count {
            let cue = cues[cueIndex]
            isPreviewingCue = cue.isPlaying()
            
            // Process effects (fades, loops, out-points)
            for eff in cue.effects {
                if eff.isPlaying() {
                    eff.process()
                }
            }
        }
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FX_midiRecieved"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleMIDIReceived(notification)
            }
        }
    }
    
    private func handleMIDIReceived(_ notification: Notification) {
        guard let data = notification.object as? String else { return }
        
        if isMIDILearning {
            midiTrigger = data
            isMIDILearning = false
            if let cueIndex = selectedCueIndex, cueIndex < cues.count {
                cues[cueIndex].midi = data
                fx.show.save()
            }
        }
    }
    
    // MARK: - Cue Actions
    
    func selectCue(at index: Int) {
        guard index >= 0 && index < cues.count else { return }
        selectedCueIndex = index
        selectedEffectIndex = nil
        
        let cue = cues[index]
        cueName = cue.getName()
        cueNotes = cue.notes
        autoFollow = cue.autoFollow
        autoFollowDelay = cue.autoFollowDelay
        autoFollowEnd = cue.autoFollowEnd
        midiTrigger = cue.midi
        
        // Reset effect editor
        resetEffectState()
        
        // Sync with engine
        fx.show.currentVersion.currentCueNo = index
        fx.show.currentVersion.currentCue = cue
    }
    
    func addCue() {
        let newCue = FxCue()
        _ = fx.show.currentVersion.addCue(newCue)
        loadShow()
        
        let newIndex = cues.count - 1
        newCue.createName(newIndex + 1)
        selectCue(at: newIndex)
        fx.show.save()
    }
    
    func insertCue(at index: Int) {
        let newCue = fx.show.currentVersion.insertCue(index)
        loadShow()
        
        if let insertedIndex = cues.firstIndex(where: { $0 === newCue }) {
            newCue.createName(insertedIndex + 1)
            selectCue(at: insertedIndex)
        }
        fx.show.save()
    }
    
    func deleteCue(at index: Int) {
        guard index >= 0 && index < cues.count else { return }
        fx.show.currentVersion.currentCueNo = index
        fx.show.currentVersion.currentCue = cues[index]
        fx.show.currentVersion.deleteCue()
        
        loadShow()
        
        if selectedCueIndex == index {
            if cues.isEmpty {
                selectedCueIndex = nil
                selectedEffectIndex = nil
            } else {
                selectCue(at: min(index, cues.count - 1))
            }
        }
    }
    
    func deleteCueSelected() {
        guard let index = selectedCueIndex else { return }
        deleteCue(at: index)
    }
    
    func copyCue() {
        guard let index = selectedCueIndex, index < cues.count else { return }
        let original = cues[index]
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: original, requiringSecureCoding: false) {
            copiedCueData = data
            canPaste = true
        }
    }
    
    func pasteCue() {
        guard let data = copiedCueData,
              let copy = try? NSKeyedUnarchiver.unarchivedObject(ofClass: FxCue.self, from: data) else { return }
        copy.name = "\(copy.getName()) (copy)"
        _ = fx.show.currentVersion.addCue(copy)
        fx.show.save()
        loadShow()
        selectCue(at: cues.count - 1)
    }
    
    func moveCueUp() {
        guard let index = selectedCueIndex, index > 0 else { return }
        fx.show.currentVersion.cues.swapAt(index, index - 1)
        fx.show.save()
        selectedCueIndex = index - 1
        loadShow()
    }
    
    func moveCueDown() {
        guard let index = selectedCueIndex, index < cues.count - 1 else { return }
        fx.show.currentVersion.cues.swapAt(index, index + 1)
        fx.show.save()
        selectedCueIndex = index + 1
        loadShow()
    }
    
    func renumberCues() {
        for (i, cue) in fx.show.currentVersion.cues.enumerated() {
            cue.createName(i + 1)
        }
        fx.show.save()
        loadShow()
        if let idx = selectedCueIndex {
            selectCue(at: idx)
        }
    }
    
    func saveCueProperties() {
        guard let index = selectedCueIndex, index < cues.count else { return }
        let cue = cues[index]
        cue.name = cueName
        cue.notes = cueNotes
        cue.autoFollow = autoFollow
        cue.autoFollowDelay = autoFollowDelay
        cue.autoFollowEnd = autoFollowEnd
        fx.show.save()
        
        // Defer published property updates to avoid "Publishing changes from within view updates"
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let updatedCues = self.cues
            self.cues = []
            self.cues = updatedCues
        }
    }
    
    func toggleMIDILearn() {
        isMIDILearning.toggle()
    }
    
    // MARK: - Effect Actions
    
    func selectEffect(at index: Int) {
        guard let cueIndex = selectedCueIndex, cueIndex < cues.count else { return }
        let cue = cues[cueIndex]
        guard index >= 0 && index < cue.effects.count else { return }
        selectedEffectIndex = index
        
        let effect = cue.effects[index]
        effectName = effect.name
        effectFile = effect.file
        effectLevel = effect.level
        effectPan = effect.pan
        fadeIn = effect.inTrans
        fadeOut = effect.outTrans
        effectDelay = effect.delay
        inPoint = effect.inPoint
        outPoint = effect.outPoint
        effectLoop = effect.loop
        effectBackground = effect.background
        isSpotEffect = effect.spotEffect
        effectOutput = effect.output
        effectDontFade = effect.dontFade
        
        // Sync engine
        cue.currentEffectNo = index
        cue.currentEffect = effect
        
        // Load audio properties
        if effect.type == fx.TYPE_AUDIO || effect.type == fx.TYPE_MUSIC {
            let duration = effect.getDuration()
            if duration > 0 {
                effectDuration = duration
            }
            // Get full file duration for trim view
            loadFileDuration(for: effect)
            // Fallback: ensure fileDuration is at least as large as outPoint
            if fileDuration <= 0 && effect.outPoint > 0 {
                fileDuration = effect.outPoint
            }
            if !effect.isPlaying() {
                currentPlaybackPosition = 0
            }
            loadWaveformData(for: effect)
            loadFullWaveformData(for: effect)
        } else {
            effectDuration = 0
            fileDuration = 0
            currentPlaybackPosition = 0
            waveformData = []
            fullWaveformData = []
        }
    }
    
    func addEffect(type: String) {
        guard let cueIndex = selectedCueIndex, cueIndex < cues.count else { return }
        let cue = cues[cueIndex]
        
        // Sync engine
        fx.show.currentVersion.currentCueNo = cueIndex
        fx.show.currentVersion.currentCue = cue
        
        if type == fx.TYPE_AUDIO {
            // Open file browser for audio
            browseForNewEffect(cue: cue, type: type)
        } else {
            // Create effect directly
            let effect = FxEffect()
            effect.type = type
            
            switch type {
            case fx.TYPE_MUSIC:
                effect.name = "Incidental Music"
            case fx.TYPE_MIDI:
                effect.name = "MIDI Message"
            case fx.TYPE_BLACK:
                effect.name = "Black"
            case fx.TYPE_IMAGE:
                effect.name = "Image"
            case fx.TYPE_VIDEO:
                effect.name = "Video"
            default: break
            }
            
            cue.addEffect(effect)
            fx.show.save()
            loadShow()
            selectCue(at: cueIndex)
            selectEffect(at: cue.effects.count - 1)
            
            // For music, also open file browser
            if type == fx.TYPE_MUSIC {
                browseForFile()
            }
        }
    }
    
    private func browseForNewEffect(cue: FxCue, type: String) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio, .mpeg4Audio, .mp3, .wav, .aiff]
        panel.title = "Select Audio File"
        panel.directoryURL = URL(fileURLWithPath: documentsPath())
        
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            DispatchQueue.main.async {
                guard let self = self, let cueIndex = self.selectedCueIndex else { return }
                
                for url in panel.urls {
                    let fileName = url.lastPathComponent
                    let destPath = documentsPath(fileName)
                    
                    if !FileManager.default.fileExists(atPath: destPath) {
                        try? FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destPath))
                    }
                    
                    let effect = FxEffect()
                    effect.name = (fileName as NSString).deletingPathExtension
                    effect.file = fileName
                    effect.type = type
                    
                    let stream = fx.audio.loadPreview(destPath)
                    if stream > 0 {
                        effect.outPoint = Float(fx.audio.getDur(stream))
                        fx.audio.stop(stream)
                    }
                    
                    cue.addEffect(effect)
                }
                
                fx.show.save()
                self.loadShow()
                self.selectCue(at: cueIndex)
                if cue.effects.count > 0 {
                    self.selectEffect(at: cue.effects.count - 1)
                }
            }
        }
    }
    
    func deleteEffect(at index: Int) {
        guard let cueIndex = selectedCueIndex, cueIndex < cues.count else { return }
        let cue = cues[cueIndex]
        guard index >= 0 && index < cue.effects.count else { return }
        
        cue.effects.remove(at: index)
        fx.show.save()
        
        selectedEffectIndex = nil
        resetEffectState()
        loadShow()
        selectCue(at: cueIndex)
    }
    
    func deleteEffectSelected() {
        guard let index = selectedEffectIndex else { return }
        deleteEffect(at: index)
    }
    
    func moveEffectUp() {
        guard let cueIndex = selectedCueIndex, cueIndex < cues.count,
              let effectIndex = selectedEffectIndex, effectIndex > 0 else { return }
        let cue = cues[cueIndex]
        cue.effects.swapAt(effectIndex, effectIndex - 1)
        selectedEffectIndex = effectIndex - 1
        fx.show.save()
        loadShow()
        selectCue(at: cueIndex)
    }
    
    func moveEffectDown() {
        guard let cueIndex = selectedCueIndex, cueIndex < cues.count,
              let effectIndex = selectedEffectIndex else { return }
        let cue = cues[cueIndex]
        guard effectIndex < cue.effects.count - 1 else { return }
        cue.effects.swapAt(effectIndex, effectIndex + 1)
        selectedEffectIndex = effectIndex + 1
        fx.show.save()
        loadShow()
        selectCue(at: cueIndex)
    }
    
    func saveEffectProperties() {
        guard let cueIndex = selectedCueIndex, cueIndex < cues.count,
              let effectIndex = selectedEffectIndex else { return }
        let cue = cues[cueIndex]
        guard effectIndex < cue.effects.count else { return }
        let effect = cue.effects[effectIndex]
        
        effect.name = effectName
        effect.level = effectLevel
        effect.pan = effectPan
        effect.inTrans = fadeIn
        effect.outTrans = fadeOut
        effect.delay = effectDelay
        effect.inPoint = inPoint
        effect.outPoint = outPoint
        effect.loop = effectLoop
        effect.background = effectBackground
        effect.spotEffect = isSpotEffect
        effect.output = effectOutput
        effect.dontFade = effectDontFade
        
        // Live update if playing
        if effect.isPlaying() {
            fx.audio.setLevel(effect.stream, level: effectLevel)
            fx.audio.setPan(effect.stream, level: effectPan)
        }
        
        fx.show.save()
        
        // Defer published property updates to avoid "Publishing changes from within view updates"
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Update duration
            let duration = effect.getDuration()
            if duration > 0 {
                self.effectDuration = duration
            }
            // Force refresh effect list
            self.objectWillChange.send()
        }
    }
    
    func browseForFile() {
        guard let cueIndex = selectedCueIndex, cueIndex < cues.count,
              let effectIndex = selectedEffectIndex else { return }
        
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio, .mpeg4Audio, .mp3, .wav, .aiff]
        panel.title = "Select Audio File"
        panel.directoryURL = URL(fileURLWithPath: documentsPath())
        
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            DispatchQueue.main.async {
                guard let self = self else { return }
                let fileName = url.lastPathComponent
                let destPath = documentsPath(fileName)
                
                if !FileManager.default.fileExists(atPath: destPath) {
                    try? FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destPath))
                }
                
                let cue = fx.show.currentVersion.cues[cueIndex]
                let effect = cue.effects[effectIndex]
                effect.file = fileName
                if effect.name.isEmpty || effect.name == "New Event" {
                    effect.name = (fileName as NSString).deletingPathExtension
                }
                
                let stream = fx.audio.loadPreview(destPath)
                if stream > 0 {
                    effect.outPoint = Float(fx.audio.getDur(stream))
                    fx.audio.stop(stream)
                }
                
                self.effectFile = fileName
                self.effectName = effect.name
                self.outPoint = effect.outPoint
                self.inPoint = effect.inPoint
                self.fileDuration = effect.outPoint  // New file, outPoint = full duration
                self.effectDuration = effect.getDuration()
                fx.show.save()
                
                // Load waveforms
                self.loadWaveformData(for: effect)
                self.loadFullWaveformData(for: effect)
            }
        }
    }
    
    // MARK: - Preview / Transport
    
    func togglePreviewEffect() {
        guard let effect = currentEffect else { return }
        
        if effect.isPlaying() {
            effect.previewEnd()
            isPreviewingEffect = false
        } else {
            effect.previewStart()
            isPreviewingEffect = true
        }
    }
    
    func togglePreviewCue() {
        guard let cueIndex = selectedCueIndex, cueIndex < cues.count else { return }
        let cue = cues[cueIndex]
        
        if cue.isPlaying() {
            cue.stop()
            isPreviewingCue = false
        } else {
            cue.play()
            isPreviewingCue = true
        }
    }
    
    func togglePlayFromPosition() {
        guard let effect = currentEffect else { return }
        
        if effect.isPlaying() {
            effect.previewEnd()
            isPreviewingEffect = false
        } else {
            effect.stream = fx.audio.loadPreview(documentsPath(effect.file))
            fx.audio.play(effect.stream)
            let absolutePosition = effect.inPoint + currentPlaybackPosition
            fx.audio.setPos(effect.stream, position: absolutePosition)
            fx.audio.setLevel(effect.stream, level: effect.level)
            fx.audio.setPan(effect.stream, level: effect.pan)
            isPreviewingEffect = true
        }
    }
    
    func seekToPosition(_ position: Float) {
        guard let effect = currentEffect else { return }
        currentPlaybackPosition = position
        
        if effect.isPlaying() {
            let absolutePosition = effect.inPoint + position
            fx.audio.setPos(effect.stream, position: absolutePosition)
        }
    }
    
    // MARK: - Waveform
    
    private func loadWaveformData(for effect: FxEffect) {
        guard !effect.file.isEmpty else {
            waveformData = []
            return
        }
        let filePath = documentsPath(effect.file)
        let segmentCount = 200
        let fromTime = effect.inPoint
        let toTime = effect.outPoint > effect.inPoint ? effect.outPoint : effect.inPoint + 1
        
        DispatchQueue.global(qos: .userInitiated).async {
            let data = fx.getWaveformData(filePath: filePath, segments: segmentCount, fromTime: fromTime, toTime: toTime)
            DispatchQueue.main.async { [weak self] in
                self?.waveformData = data
            }
        }
    }
    
    /// Load full-file waveform data (not trimmed) for the overview trim view
    private func loadFullWaveformData(for effect: FxEffect) {
        guard !effect.file.isEmpty else {
            fullWaveformData = []
            return
        }
        let filePath = documentsPath(effect.file)
        let segmentCount = 200
        
        DispatchQueue.global(qos: .userInitiated).async {
            let data = fx.getWaveformData(filePath: filePath, segments: segmentCount)
            DispatchQueue.main.async { [weak self] in
                self?.fullWaveformData = data
            }
        }
    }
    
    /// Load the total file duration (not the trimmed duration)
    private func loadFileDuration(for effect: FxEffect) {
        guard !effect.file.isEmpty else {
            fileDuration = 0
            return
        }
        let filePath = documentsPath(effect.file)
        
        // Use FxEngine preview to get full file duration
        fx.loadPreview(filePath)
        let dur = fx.getPreviewDurationSecs()
        if dur > 0 {
            fileDuration = dur
            print("📏 File duration loaded: \(dur)s for \(effect.file)")
        } else {
            // Fallback: if we can't get file duration, use outPoint as best guess
            // (outPoint is set to full file length on initial import)
            fileDuration = effect.outPoint > 0 ? effect.outPoint : 0
            print("📏 File duration fallback to outPoint: \(fileDuration)s")
        }
    }
    
    // MARK: - Trim Controls
    
    /// Reset in/out points to the full file duration
    func resetTrimPoints() {
        guard let effect = currentEffect, fileDuration > 0 else { return }
        inPoint = 0
        outPoint = fileDuration
        effect.inPoint = 0
        effect.outPoint = fileDuration
        effectDuration = effect.getDuration()
        currentPlaybackPosition = 0
        fx.show.save()
        loadWaveformData(for: effect)
        objectWillChange.send()
    }
    
    /// Set in point to current playback position
    func setInPointAtPlayhead() {
        guard let effect = currentEffect else { return }
        // Convert playback position (relative to trimmed region) to absolute file position
        let absolutePos = effect.inPoint + currentPlaybackPosition
        let newIn = min(absolutePos, outPoint - 0.1)
        inPoint = max(0, newIn)
        effect.inPoint = inPoint
        effectDuration = effect.getDuration()
        if currentPlaybackPosition < 0 {
            currentPlaybackPosition = 0
        }
        fx.show.save()
        loadWaveformData(for: effect)
        objectWillChange.send()
    }
    
    /// Set out point to current playback position
    func setOutPointAtPlayhead() {
        guard let effect = currentEffect else { return }
        let absolutePos = effect.inPoint + currentPlaybackPosition
        let newOut = max(absolutePos, inPoint + 0.1)
        outPoint = min(newOut, fileDuration)
        effect.outPoint = outPoint
        effectDuration = effect.getDuration()
        fx.show.save()
        loadWaveformData(for: effect)
        objectWillChange.send()
    }
    
    /// Update in point from trim handle drag (absolute file position)
    func updateInPointAbsolute(_ newInPoint: Float) {
        guard let effect = currentEffect else { return }
        let clamped = max(0, min(newInPoint, outPoint - 0.1))
        inPoint = clamped
        effect.inPoint = clamped
        effectDuration = effect.getDuration()
        fx.show.save()
        // Don't reload waveform during drag (too expensive) - just on end
    }
    
    /// Update out point from trim handle drag (absolute file position)
    func updateOutPointAbsolute(_ newOutPoint: Float) {
        guard let effect = currentEffect else { return }
        let clamped = min(fileDuration, max(newOutPoint, inPoint + 0.1))
        outPoint = clamped
        effect.outPoint = clamped
        effectDuration = effect.getDuration()
        fx.show.save()
    }
    
    /// Called when trim handle drag ends - reload trimmed waveform
    func finishTrimDrag() {
        guard let effect = currentEffect else { return }
        loadWaveformData(for: effect)
        objectWillChange.send()
    }
    
    /// Preview a short snippet around the in point
    func sampleInPoint() {
        guard let effect = currentEffect, !effect.file.isEmpty else { return }
        
        // Stop any current playback
        if effect.isPlaying() {
            effect.previewEnd()
        }
        
        // Load and play from just before the in point
        effect.stream = fx.audio.loadPreview(documentsPath(effect.file))
        fx.audio.play(effect.stream)
        let startPos = max(0, inPoint - 0.1)
        fx.audio.setPos(effect.stream, position: startPos)
        fx.audio.setLevel(effect.stream, level: effect.level)
        fx.audio.setPan(effect.stream, level: effect.pan)
        isPreviewingEffect = true
        
        // Stop after a short sample
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            effect.previewEnd()
            self.isPreviewingEffect = false
            self.currentPlaybackPosition = 0
        }
    }
    
    /// Preview a short snippet around the out point
    func sampleOutPoint() {
        guard let effect = currentEffect, !effect.file.isEmpty else { return }
        
        if effect.isPlaying() {
            effect.previewEnd()
        }
        
        effect.stream = fx.audio.loadPreview(documentsPath(effect.file))
        fx.audio.play(effect.stream)
        let startPos = max(0, outPoint - 0.5)
        fx.audio.setPos(effect.stream, position: startPos)
        fx.audio.setLevel(effect.stream, level: effect.level)
        fx.audio.setPan(effect.stream, level: effect.pan)
        isPreviewingEffect = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            effect.previewEnd()
            self.isPreviewingEffect = false
            self.currentPlaybackPosition = max(0, self.effectDuration - 0.5)
        }
    }
    
    /// Jump playhead to in point
    func goToInPoint() {
        currentPlaybackPosition = 0
        if let effect = currentEffect, effect.isPlaying() {
            fx.audio.setPos(effect.stream, position: inPoint)
        }
    }
    
    /// Jump playhead to out point
    func goToOutPoint() {
        currentPlaybackPosition = effectDuration
        if let effect = currentEffect, effect.isPlaying() {
            fx.audio.setPos(effect.stream, position: outPoint)
        }
    }
    
    // MARK: - Helpers
    
    private func resetEffectState() {
        effectName = ""
        effectFile = ""
        effectLevel = 1.0
        effectPan = 0
        fadeIn = 0
        fadeOut = 0
        effectDelay = 0
        inPoint = 0
        outPoint = 0
        effectLoop = false
        effectBackground = false
        isSpotEffect = false
        effectOutput = 0
        effectDontFade = false
        effectDuration = 0
        fileDuration = 0
        currentPlaybackPosition = 0
        waveformData = []
        fullWaveformData = []
        isPreviewingEffect = false
    }
}
