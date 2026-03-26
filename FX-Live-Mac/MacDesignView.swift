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
import AVFoundation

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
                    MacCueRow(cue: cue, index: index, isSelected: viewModel.selectedCueIndex == index, refreshID: viewModel.cueListRefreshID)
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
                            Button("Insert Cue After") { viewModel.insertCueAfter(at: index) }
                            Button("Duplicate") { viewModel.duplicateCue(at: index) }
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
    let refreshID: Int  // Forces row redraw when cue properties change
    
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
                    .onChange(of: viewModel.cueName) { _, _ in
                        viewModel.saveCueProperties()
                    }
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
                    
                    if effect.output > 0 || !effect.additionalOutputs.isEmpty {
                        let allOutputLabels = effect.allOutputs.sorted().map { OutputBus.labelFor($0) }.joined()
                        Text(allOutputLabels)
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

// MARK: - Full Waveform Trim View (Zoomable)

/// Shows the complete audio file waveform with draggable in/out trim handles.
/// Scroll/trackpad-swipe to pan when zoomed. Use zoom buttons or pinch to zoom.
/// Drag trim handle markers to adjust in/out points.
struct MacFullWaveformTrimView: View {
    @ObservedObject var viewModel: MacDesignViewModel
    @State private var draggingHandle: TrimHandle? = nil
    
    private enum TrimHandle { case inPoint, outPoint }
    
    private let waveformHeight: CGFloat = 100
    private let rulerHeight: CGFloat = 22
    private let handleWidth: CGFloat = 20
    
    private var barCount: Int {
        min(Int(CGFloat(200) * viewModel.trimZoomLevel), 2000)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            trimHeaderRow
            
            GeometryReader { outerGeo in
                let viewportWidth = outerGeo.size.width
                let contentWidth = viewportWidth * viewModel.trimZoomLevel
                
                AlwaysScrollableHorizontalView(
                    contentWidth: contentWidth,
                    contentHeight: waveformHeight + rulerHeight
                ) {
                    VStack(spacing: 0) {
                        // Time ruler
                        trimTimeRuler(contentWidth: contentWidth)
                            .frame(width: contentWidth, height: rulerHeight)
                        
                        // Waveform layer
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color(nsColor: .textBackgroundColor))
                            
                            trimWaveformCanvas(contentWidth: contentWidth)
                            trimDimmedRegions(contentWidth: contentWidth)
                                .allowsHitTesting(false)
                            trimPlayhead(contentWidth: contentWidth)
                                .allowsHitTesting(false)
                            
                            if viewModel.fileDuration <= 0 {
                                Text("No audio loaded")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            
                            // Draggable trim handles
                            if viewModel.fileDuration > 0 {
                                trimHandleOverlay(
                                    label: "IN", color: .green,
                                    fraction: CGFloat(viewModel.inPoint / viewModel.fileDuration),
                                    contentWidth: contentWidth,
                                    handleType: .inPoint
                                )
                                
                                trimHandleOverlay(
                                    label: "OUT", color: .orange,
                                    fraction: CGFloat(viewModel.outPoint / viewModel.fileDuration),
                                    contentWidth: contentWidth,
                                    handleType: .outPoint
                                )
                            }
                        }
                        .frame(width: contentWidth, height: waveformHeight)
                        .coordinateSpace(name: "trimWaveform")
                    }
                }
                .frame(height: waveformHeight + rulerHeight + (viewModel.trimZoomLevel > 1 ? 15 : 0))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            draggingHandle != nil ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.3),
                            lineWidth: draggingHandle != nil ? 1.5 : 0.5
                        )
                )
            }
            .frame(height: waveformHeight + rulerHeight + (viewModel.trimZoomLevel > 1 ? 15 : 0))
            
            trimTimeLabelsRow
        }
    }
    
    // MARK: - Draggable Trim Handle
    
    private func trimHandleOverlay(label: String, color: Color, fraction: CGFloat, contentWidth: CGFloat, handleType: TrimHandle) -> some View {
        let x = contentWidth * fraction
        
        return ZStack {
            // Vertical line
            Rectangle()
                .fill(color)
                .frame(width: draggingHandle == handleType ? 3 : 2, height: waveformHeight)
                .shadow(color: color.opacity(0.6), radius: draggingHandle == handleType ? 4 : 2)
            
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    )
                
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 6))
                    .foregroundColor(color)
                    .offset(y: -2)
                
                Spacer()
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 14, height: 22)
                    .overlay(
                        VStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 0.5)
                                    .fill(Color.white.opacity(0.6))
                                    .frame(width: 6, height: 1)
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
            DragGesture(minimumDistance: 1, coordinateSpace: .named("trimWaveform"))
                .onChanged { value in
                    draggingHandle = handleType
                    let newX = value.startLocation.x + value.translation.width
                    let newFrac = Float(max(0, min(newX / contentWidth, 1)))
                    let timePos = newFrac * viewModel.fileDuration
                    switch handleType {
                    case .inPoint:
                        viewModel.updateInPointAbsolute(timePos)
                    case .outPoint:
                        viewModel.updateOutPointAbsolute(timePos)
                    }
                }
                .onEnded { _ in
                    draggingHandle = nil
                    viewModel.finishTrimDrag()
                }
        )
        .onHover { hovering in
            if hovering { NSCursor.resizeLeftRight.push() }
            else { NSCursor.pop() }
        }
    }
    
    // MARK: - Header
    
    private var trimHeaderRow: some View {
        HStack(spacing: 8) {
            Text("FULL FILE WAVEFORM")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            
            if viewModel.fileDuration > 0 && viewModel.effectDuration > 0 {
                Text("Trimmed: \(formatDetailedTime(viewModel.effectDuration))")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.accentColor.opacity(0.6)))
            }
            
            Spacer()
            
            // Zoom controls
            if viewModel.fileDuration > 0 {
                HStack(spacing: 4) {
                    Button(action: { viewModel.zoomOutTrimView() }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.trimZoomLevel <= 1.0)
                    .help("Zoom Out")
                    
                    Text("\(Int(viewModel.trimZoomLevel * 100))%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 38)
                    
                    Button(action: { viewModel.zoomInTrimView() }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.trimZoomLevel >= 20.0)
                    .help("Zoom In")
                    
                    Divider().frame(height: 12)
                    
                    Button(action: { viewModel.resetTrimZoom() }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .help("Fit to Window")
                    .disabled(viewModel.trimZoomLevel <= 1.0)
                    
                    Button(action: { viewModel.zoomToTrimRegion() }) {
                        Image(systemName: "crop")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .help("Zoom to Trim Region")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .controlBackgroundColor)))
            }
            
            if viewModel.fileDuration > 0 {
                Text("File: \(formatDetailedTime(viewModel.fileDuration))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Time Ruler
    
    private func trimTimeRuler(contentWidth: CGFloat) -> some View {
        Canvas { context, size in
            let duration = viewModel.fileDuration
            guard duration > 0 else { return }
            
            let pixelsPerSecond = size.width / CGFloat(duration)
            let tickInterval = rulerTickInterval(pixelsPerSecond: pixelsPerSecond)
            
            var time: Float = 0
            while time <= duration {
                let x = CGFloat(time / duration) * size.width
                
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: x, y: size.height))
                    p.addLine(to: CGPoint(x: x, y: size.height - 10))
                }, with: .color(.secondary.opacity(0.6)), lineWidth: 0.5)
                
                context.draw(
                    Text(formatDetailedTime(time))
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary),
                    at: CGPoint(x: x + 2, y: 6), anchor: .leading
                )
                
                if tickInterval > 0 {
                    for sub in 1..<4 {
                        let subTime = time + tickInterval * Float(sub) / 4.0
                        if subTime > duration { break }
                        let subX = CGFloat(subTime / duration) * size.width
                        context.stroke(Path { p in
                            p.move(to: CGPoint(x: subX, y: size.height))
                            p.addLine(to: CGPoint(x: subX, y: size.height - 5))
                        }, with: .color(.secondary.opacity(0.3)), lineWidth: 0.5)
                    }
                }
                
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
    
    private func trimWaveformCanvas(contentWidth: CGFloat) -> some View {
        let inFrac = viewModel.fileDuration > 0 ? Float(viewModel.inPoint / viewModel.fileDuration) : Float(0)
        let outFrac = viewModel.fileDuration > 0 ? Float(viewModel.outPoint / viewModel.fileDuration) : Float(1)
        let n = barCount
        return Canvas { context, size in
            let barW = max(1.0, size.width / CGFloat(n) - 0.5)
            for i in 0..<n {
                let f = Float(i) / Float(n)
                let inTrim = f >= inFrac && f <= outFrac
                let h = trimBarHeight(for: i, totalBars: n)
                let bh = size.height * h
                let rect = CGRect(x: CGFloat(i) * (barW + 0.5), y: (size.height - bh) / 2, width: barW, height: bh)
                context.fill(Path(roundedRect: rect, cornerRadius: 0.5),
                             with: .color(inTrim ? .accentColor.opacity(0.55) : .gray.opacity(0.15)))
            }
        }
        .frame(width: contentWidth, height: waveformHeight)
        .allowsHitTesting(false)
    }
    
    // MARK: - Dimmed Regions
    
    private func trimDimmedRegions(contentWidth: CGFloat) -> some View {
        let inX = viewModel.fileDuration > 0 ? contentWidth * CGFloat(viewModel.inPoint / viewModel.fileDuration) : 0
        let outX = viewModel.fileDuration > 0 ? contentWidth * CGFloat(viewModel.outPoint / viewModel.fileDuration) : contentWidth
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
    
    private func trimPlayhead(contentWidth: CGFloat) -> some View {
        Group {
            if viewModel.fileDuration > 0 && viewModel.effectDuration > 0 {
                let posX = contentWidth * CGFloat(min(max((viewModel.inPoint + viewModel.currentPlaybackPosition) / viewModel.fileDuration, 0), 1))
                Rectangle()
                    .fill(viewModel.isPreviewingEffect ? Color.green : Color.white)
                    .frame(width: 2)
                    .shadow(color: (viewModel.isPreviewingEffect ? Color.green : .white).opacity(0.6), radius: 2)
                    .offset(x: posX - 1)
            }
        }
    }
    
    // MARK: - Time Labels
    
    private var trimTimeLabelsRow: some View {
        Group {
            if viewModel.fileDuration > 0 {
                HStack {
                    Text(formatDetailedTime(0))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "arrowtriangle.right.fill").font(.system(size: 6))
                        Text("IN \(formatDetailedTime(viewModel.inPoint))")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }.foregroundColor(.green)
                    Spacer()
                    HStack(spacing: 3) {
                        Text("OUT \(formatDetailedTime(viewModel.outPoint))")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        Image(systemName: "arrowtriangle.left.fill").font(.system(size: 6))
                    }.foregroundColor(.orange)
                    Spacer()
                    Text(formatDetailedTime(viewModel.fileDuration))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Bar Height
    
    private func trimBarHeight(for index: Int, totalBars: Int) -> CGFloat {
        let data = viewModel.trimZoomLevel > 1.5 && !viewModel.hiResFullWaveformData.isEmpty
            ? viewModel.hiResFullWaveformData : viewModel.fullWaveformData
        if !data.isEmpty {
            let i = min(index * data.count / totalBars, data.count - 1)
            return max(0.03, min(0.95, 0.03 + CGFloat(data[i]) * 0.92))
        }
        let n = Double(index) / Double(totalBars)
        return max(0.03, min(0.95, CGFloat(0.15 + (sin(n * .pi * 6) * 0.3 + sin(n * .pi * 13) * 0.15 + 0.5) * sin(n * .pi) * 0.5)))
    }
    
    private func formatDetailedTime(_ seconds: Float) -> String {
        let total = max(0, seconds)
        let mins = Int(total) / 60
        let secs = total - Float(mins * 60)
        return String(format: "%d:%05.2f", mins, secs)
    }
}

// MARK: - Always-Visible Horizontal ScrollView (NSScrollView wrapper)

/// An NSScrollView wrapper that always shows the horizontal scrollbar when content is wider than the viewport.
/// This solves macOS's default behavior of auto-hiding scrollbars.
struct AlwaysScrollableHorizontalView<Content: View>: NSViewRepresentable {
    let contentWidth: CGFloat
    let contentHeight: CGFloat
    @ViewBuilder let content: () -> Content
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        
        let hostingView = NSHostingView(rootView: content())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(hostingView)
        
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            hostingView.topAnchor.constraint(equalTo: documentView.topAnchor),
            hostingView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
        ])
        
        scrollView.documentView = documentView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // Update the hosted SwiftUI content
        if let documentView = scrollView.documentView,
           let hostingView = documentView.subviews.first as? NSHostingView<Content> {
            hostingView.rootView = content()
        }
        
        // Update document size
        scrollView.documentView?.frame.size = NSSize(width: contentWidth, height: contentHeight)
        
        // Show/hide scroller based on whether content overflows
        scrollView.hasHorizontalScroller = contentWidth > scrollView.bounds.width
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
                        TextField("", value: $viewModel.inPoint, format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 65)
                            .font(.system(size: 12, design: .monospaced))
                            .onSubmit { viewModel.saveEffectProperties() }
                        Text("s").font(.caption).foregroundColor(.secondary)
                        Button(action: { viewModel.setInPointAtPlayhead() }) {
                            Image(systemName: "location.fill").font(.system(size: 12))
                        }
                        .help("Set in point at playhead").buttonStyle(.bordered)
                        Button(action: { viewModel.sampleInPoint() }) {
                            Image(systemName: "speaker.wave.2.fill").font(.system(size: 12))
                        }
                        .help("Preview in point").buttonStyle(.bordered).tint(.green)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text(" ").font(.system(size: 10, weight: .semibold))
                    HStack(spacing: 8) {
                        Button(action: { viewModel.resetTrimPoints() }) {
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.counterclockwise").font(.system(size: 14))
                                Text("Reset").font(.system(size: 9))
                            }
                        }
                        .help("Reset to full file").buttonStyle(.bordered)
                        .disabled(viewModel.fileDuration <= 0)
                        
                        Button(action: { viewModel.autoTrimSilence() }) {
                            VStack(spacing: 2) {
                                Image(systemName: "waveform.badge.minus").font(.system(size: 14))
                                Text("Auto Trim").font(.system(size: 9))
                            }
                        }
                        .help("Auto-trim silence from start and end").buttonStyle(.bordered).tint(.blue)
                        .disabled(viewModel.fileDuration <= 0)
                    }
                }
                
                Spacer()
                
                // Out point controls
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Out Point")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)
                    HStack(spacing: 6) {
                        Button(action: { viewModel.sampleOutPoint() }) {
                            Image(systemName: "speaker.wave.2.fill").font(.system(size: 12))
                        }
                        .help("Preview out point").buttonStyle(.bordered).tint(.orange)
                        Button(action: { viewModel.setOutPointAtPlayhead() }) {
                            Image(systemName: "location.fill").font(.system(size: 12))
                        }
                        .help("Set out point at playhead").buttonStyle(.bordered)
                        TextField("", value: $viewModel.outPoint, format: .number.precision(.fractionLength(2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 65)
                            .font(.system(size: 12, design: .monospaced))
                            .onSubmit { viewModel.saveEffectProperties() }
                        Text("s").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
        }
        .padding(.horizontal)
    }
}

// MARK: - Audio Timeline View (Mac) - Trimmed Region Playback (Zoomable)

struct MacAudioTimelineView: View {
    @ObservedObject var viewModel: MacDesignViewModel
    
    private let waveformHeight: CGFloat = 100
    private let rulerHeight: CGFloat = 22
    
    /// Dynamic bar count scales with zoom
    private var barCount: Int {
        let base = 200
        let zoomed = Int(CGFloat(base) * viewModel.timelineZoomLevel)
        return min(zoomed, 2000)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Timeline header row with zoom controls
            timelineHeaderRow
            
            // ScrollView-based zoomed timeline with visible scrollbar
            GeometryReader { outerGeo in
                let viewportWidth = outerGeo.size.width
                let contentWidth = viewportWidth * viewModel.timelineZoomLevel
                
                AlwaysScrollableHorizontalView(
                    contentWidth: contentWidth,
                    contentHeight: waveformHeight + rulerHeight
                ) {
                    VStack(spacing: 0) {
                        // Time ruler
                        timelineRuler(contentWidth: contentWidth)
                            .frame(width: contentWidth, height: rulerHeight)
                        
                        // Waveform + overlays — click/drag to scrub
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color(nsColor: .textBackgroundColor))
                            
                            timelineWaveformCanvas(contentWidth: contentWidth)
                                .allowsHitTesting(false)
                            
                            if viewModel.effectDuration > 0 && viewModel.fadeIn > 0 {
                                timelineFadeInOverlay(contentWidth: contentWidth)
                                    .allowsHitTesting(false)
                            }
                            
                            if viewModel.effectDuration > 0 && viewModel.fadeOut > 0 {
                                timelineFadeOutOverlay(contentWidth: contentWidth)
                                    .allowsHitTesting(false)
                            }
                            
                            // Progress fill
                            if viewModel.effectDuration > 0 {
                                let progress = CGFloat(viewModel.currentPlaybackPosition / viewModel.effectDuration)
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.05)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: contentWidth * min(max(progress, 0), 1), height: waveformHeight)
                                    .allowsHitTesting(false)
                            }
                            
                            timelinePlayhead(contentWidth: contentWidth)
                                .allowsHitTesting(false)
                            
                            if viewModel.effectDuration <= 0 {
                                Text("No audio loaded")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            
                            // Scrub/seek overlay
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 1)
                                        .onChanged { value in
                                            viewModel.isDraggingTimeline = true
                                            let fraction = Float(value.location.x / contentWidth)
                                            let clampedFraction = min(max(fraction, 0), 1)
                                            viewModel.seekToPosition(clampedFraction * viewModel.effectDuration)
                                        }
                                        .onEnded { _ in
                                            viewModel.isDraggingTimeline = false
                                        }
                                )
                                .onTapGesture { location in
                                    guard viewModel.effectDuration > 0 else { return }
                                    let fraction = Float(location.x / contentWidth)
                                    let clamped = min(max(fraction, 0), 1)
                                    viewModel.seekToPosition(clamped * viewModel.effectDuration)
                                }
                        }
                        .frame(width: contentWidth, height: waveformHeight)
                    }
                }
                .frame(height: waveformHeight + rulerHeight + (viewModel.timelineZoomLevel > 1 ? 15 : 0))
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
            }
            .frame(height: waveformHeight + rulerHeight + (viewModel.timelineZoomLevel > 1 ? 15 : 0))
            
            // Time markers row
            if viewModel.effectDuration > 0 {
                timeMarkersRow
            }
        }
    }
    
    // MARK: - Header Row
    
    private var timelineHeaderRow: some View {
        HStack(spacing: 8) {
            Text("PLAYBACK TIMELINE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            
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
            
            // Zoom controls
            if viewModel.effectDuration > 0 {
                HStack(spacing: 4) {
                    Button(action: { viewModel.zoomOutTimeline() }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.timelineZoomLevel <= 1.0)
                    .help("Zoom Out")
                    
                    Text("\(Int(viewModel.timelineZoomLevel * 100))%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 38)
                    
                    Button(action: { viewModel.zoomInTimeline() }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.timelineZoomLevel >= 20.0)
                    .help("Zoom In")
                    
                    Divider().frame(height: 12)
                    
                    Button(action: { viewModel.resetTimelineZoom() }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .help("Fit to Window")
                    .disabled(viewModel.timelineZoomLevel <= 1.0)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
            
            // Transport controls
            Button(action: { viewModel.goToInPoint() }) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundColor(.green)
            .help("Go to In point")
            .disabled(viewModel.effectDuration <= 0)
            
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
    }
    
    // MARK: - Time Ruler
    
    private func timelineRuler(contentWidth: CGFloat) -> some View {
        Canvas { context, size in
            let duration = viewModel.effectDuration
            guard duration > 0 else { return }
            
            let pixelsPerSecond = contentWidth / CGFloat(duration)
            let tickInterval = timelineTickInterval(pixelsPerSecond: pixelsPerSecond)
            
            var time: Float = 0
            while time <= duration {
                let x = CGFloat(time / duration) * contentWidth
                
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: x, y: size.height))
                    p.addLine(to: CGPoint(x: x, y: size.height - 10))
                }, with: .color(.secondary.opacity(0.6)), lineWidth: 0.5)
                
                context.draw(
                    Text(formatTimeValue(time))
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary),
                    at: CGPoint(x: x + 2, y: 6), anchor: .leading
                )
                
                if tickInterval > 0 {
                    for sub in 1..<4 {
                        let subTime = time + tickInterval * Float(sub) / 4.0
                        if subTime > duration { break }
                        let subX = CGFloat(subTime / duration) * contentWidth
                        context.stroke(Path { p in
                            p.move(to: CGPoint(x: subX, y: size.height))
                            p.addLine(to: CGPoint(x: subX, y: size.height - 5))
                        }, with: .color(.secondary.opacity(0.3)), lineWidth: 0.5)
                    }
                }
                
                time += tickInterval
                if tickInterval <= 0 { break }
            }
            
            context.stroke(Path { p in
                p.move(to: CGPoint(x: 0, y: size.height - 0.5))
                p.addLine(to: CGPoint(x: contentWidth, y: size.height - 0.5))
            }, with: .color(.secondary.opacity(0.3)), lineWidth: 0.5)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    private func timelineTickInterval(pixelsPerSecond: CGFloat) -> Float {
        for interval in [Float(0.1), 0.25, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300] {
            if pixelsPerSecond * CGFloat(interval) >= 60 { return interval }
        }
        return 300
    }
    
    // MARK: - Waveform Canvas
    
    private func timelineWaveformCanvas(contentWidth: CGFloat) -> some View {
        let currentBarCount = barCount
        let playProgress = viewModel.effectDuration > 0
            ? viewModel.currentPlaybackPosition / viewModel.effectDuration
            : Float(0)
        let fadeInFrac = viewModel.effectDuration > 0 ? viewModel.fadeIn / viewModel.effectDuration : Float(0)
        let fadeOutStart = viewModel.effectDuration > 0 ? 1.0 - viewModel.fadeOut / viewModel.effectDuration : Float(1)
        
        return Canvas { context, size in
            let barWidth = max(1.0, size.width / CGFloat(currentBarCount) - 0.5)
            let spacing: CGFloat = 0.5
            
            for i in 0..<currentBarCount {
                let barFrac = Float(i) / Float(currentBarCount)
                let height = timelineBarHeight(for: i, totalBars: currentBarCount)
                let isPlayed = barFrac < playProgress
                let inFade = viewModel.fadeIn > 0 && barFrac < fadeInFrac
                let outFade = viewModel.fadeOut > 0 && barFrac > fadeOutStart
                
                let x = CGFloat(i) * (barWidth + spacing)
                let barH = size.height * height
                let y = (size.height - barH) / 2
                
                let rect = CGRect(x: x, y: y, width: barWidth, height: barH)
                let color = timelineBarColor(isPlayed: isPlayed, inFade: inFade, outFade: outFade)
                context.fill(Path(roundedRect: rect, cornerRadius: 0.5), with: .color(color))
            }
        }
        .frame(width: contentWidth, height: waveformHeight)
    }
    
    private func timelineBarColor(isPlayed: Bool, inFade: Bool, outFade: Bool) -> Color {
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
    
    // MARK: - Fade Overlays
    
    private func timelineFadeInOverlay(contentWidth: CGFloat) -> some View {
        let fadeFraction = CGFloat(viewModel.fadeIn / viewModel.effectDuration)
        let fadeWidth = contentWidth * min(fadeFraction, 1)
        
        return ZStack(alignment: .leading) {
            LinearGradient(
                colors: [Color.green.opacity(0.25), Color.green.opacity(0.0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: fadeWidth, height: waveformHeight)
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: waveformHeight))
                path.addLine(to: CGPoint(x: fadeWidth, y: waveformHeight * 0.2))
            }
            .stroke(Color.green.opacity(0.6), lineWidth: 1.5)
            .frame(width: fadeWidth, height: waveformHeight)
        }
    }
    
    private func timelineFadeOutOverlay(contentWidth: CGFloat) -> some View {
        let fadeFraction = CGFloat(viewModel.fadeOut / viewModel.effectDuration)
        let fadeWidth = contentWidth * min(fadeFraction, 1)
        let fadeStartX = contentWidth - fadeWidth
        
        return ZStack(alignment: .trailing) {
            LinearGradient(
                colors: [Color.red.opacity(0.0), Color.red.opacity(0.25)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: fadeWidth, height: waveformHeight)
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: waveformHeight * 0.2))
                path.addLine(to: CGPoint(x: fadeWidth, y: waveformHeight))
            }
            .stroke(Color.red.opacity(0.6), lineWidth: 1.5)
            .frame(width: fadeWidth, height: waveformHeight)
        }
        .offset(x: fadeStartX)
    }
    
    // MARK: - Playhead
    
    private func timelinePlayhead(contentWidth: CGFloat) -> some View {
        Group {
            if viewModel.effectDuration > 0 {
                let progress = CGFloat(viewModel.currentPlaybackPosition / viewModel.effectDuration)
                let clampedProgress = min(max(progress, 0), 1)
                let posX = contentWidth * clampedProgress
                
                Rectangle()
                    .fill(viewModel.isPreviewingEffect ? Color.green : Color.blue)
                    .frame(width: 2)
                    .shadow(color: (viewModel.isPreviewingEffect ? Color.green : Color.blue).opacity(0.5), radius: 2)
                    .offset(x: posX - 1)
                
                // Playhead handle at top
                Circle()
                    .fill(viewModel.isPreviewingEffect ? Color.green : Color.blue)
                    .frame(width: 10, height: 10)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .offset(x: posX - 5, y: -waveformHeight / 2 + 2)
            }
        }
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
    
    // MARK: - Bar Height
    
    private func timelineBarHeight(for index: Int, totalBars: Int) -> CGFloat {
        // Use hi-res data when zoomed
        let data = viewModel.timelineZoomLevel > 1.5 && !viewModel.hiResWaveformData.isEmpty
            ? viewModel.hiResWaveformData : viewModel.waveformData
        
        if !data.isEmpty {
            let dataIndex = index * data.count / totalBars
            let clampedIndex = min(dataIndex, data.count - 1)
            let peak = CGFloat(data[clampedIndex])
            return max(0.05, min(0.95, 0.05 + peak * 0.90))
        }
        
        // Fallback
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

// MARK: - Transport Section (Fades & Timing)

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
                            .onChange(of: viewModel.fadeIn) { _, _ in viewModel.saveEffectProperties() }
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
                            .onChange(of: viewModel.fadeOut) { _, _ in viewModel.saveEffectProperties() }
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
                            .onChange(of: viewModel.effectDelay) { _, _ in viewModel.saveEffectProperties() }
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
    
    /// Whether multi-output is active for this effect
    private var hasMultipleOutputs: Bool {
        MacOutputManager.shared.multiOutputEnabled && viewModel.effectSelectedOutputs.count > 1
    }
    
    var body: some View {
        GroupBox("Level & Pan") {
            VStack(spacing: 10) {
                // Master Level
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
                
                // Per-output volume sliders (shown when multiple outputs selected)
                if hasMultipleOutputs {
                    VStack(spacing: 6) {
                        HStack {
                            Text("Output Trims")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Reset All") {
                                viewModel.effectOutputVolumes.removeAll()
                                viewModel.saveEffectProperties()
                            }
                            .font(.system(size: 10))
                            .buttonStyle(.plain)
                            .foregroundColor(.blue)
                        }
                        
                        ForEach(viewModel.effectSelectedOutputs.sorted(), id: \.self) { busIndex in
                            MacDesignOutputVolumeSlider(
                                viewModel: viewModel,
                                busIndex: busIndex,
                                isPrimary: busIndex == viewModel.effectOutput
                            )
                        }
                    }
                    .padding(.top, 4)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    )
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

// MARK: - Design View Per-Output Volume Slider

/// Per-output trim slider for the Design View effect editor.
/// Controls the trim multiplier (0…2). Effective volume = master level × trim.
struct MacDesignOutputVolumeSlider: View {
    @ObservedObject var viewModel: MacDesignViewModel
    let busIndex: Int
    let isPrimary: Bool
    
    private var trimValue: Float {
        viewModel.effectOutputVolumes[busIndex] ?? 1.0
    }
    
    private var effectiveLevel: Float {
        viewModel.effectLevel * trimValue
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Bus label
            Text(OutputBus.labelFor(busIndex))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 20, alignment: .center)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isPrimary ? Color.blue.opacity(0.3) : Color.gray.opacity(0.3))
                )
            
            Slider(value: Binding(
                get: {
                    Double(trimValue)
                },
                set: { newValue in
                    viewModel.effectOutputVolumes[busIndex] = Float(newValue)
                    viewModel.saveEffectProperties()
                }
            ), in: 0...2)
            .tint(trimValue > 1.0 ? .orange : .green)
            
            // dB readout of effective volume
            Text(levelDBString(effectiveLevel))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 52, alignment: .trailing)
        }
    }
    
    private func levelDBString(_ level: Float) -> String {
        if level <= 0 { return "-∞ dB" }
        let dB = 20.0 * log10(level)
        if abs(dB) < 0.05 { return "0.0 dB" }
        return String(format: "%+.1f dB", dB)
    }
}

// MARK: - Common Controls Section

struct MacCommonControlsSection: View {
    @ObservedObject var viewModel: MacDesignViewModel
    let effect: FxEffect
    
    var body: some View {
        GroupBox("Options") {
            VStack(spacing: 8) {
                // Output selector (multi-select: effect can play on multiple outputs)
                HStack {
                    Text("Output:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .trailing)
                    
                    let busCount = MacOutputManager.shared.buses.count
                    
                    HStack(spacing: 2) {
                        ForEach(0..<busCount, id: \.self) { i in
                            let isSelected = viewModel.effectSelectedOutputs.contains(i)
                            Button {
                                viewModel.toggleOutput(i)
                            } label: {
                                Text(OutputBus.labelFor(i))
                                    .font(.caption)
                                    .frame(width: 28, height: 22)
                                    .background(isSelected ? Color.accentColor : Color.clear)
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
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
                            .onChange(of: viewModel.effectDelay) { _, _ in viewModel.saveEffectProperties() }
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
    @Published var cueListRefreshID: Int = 0
    
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
    @Published var effectSelectedOutputs: Set<Int> = [0]  // All selected output bus indices (multi-output)
    @Published var effectOutputVolumes: [Int: Float] = [:]  // Per-output volume overrides (bus index → level)
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
    
    // Zoom & pan state for full-file waveform trim view
    @Published var trimZoomLevel: CGFloat = 1.0       // 1.0 = fit-to-width, higher = zoomed in
    @Published var trimScrollOffset: CGFloat = 0       // Scroll offset in pixels
    @Published var trimScrollTargetFraction: CGFloat? = nil  // Set by zoomToTrimRegion, consumed by view
    
    // Zoom & pan state for playback timeline
    @Published var timelineZoomLevel: CGFloat = 1.0
    @Published var timelineScrollOffset: CGFloat = 0
    
    // Higher-res waveform data for zoomed views
    @Published var hiResFullWaveformData: [Float] = []
    @Published var hiResWaveformData: [Float] = []
    
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
        
        // Auto-select the first effect if the cue has any
        if !cue.effects.isEmpty {
            selectEffect(at: 0)
        }
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
    
    func insertCueAfter(at index: Int) {
        let insertIndex = index + 1
        if insertIndex >= cues.count {
            // Insert at end
            addCue()
        } else {
            let newCue = fx.show.currentVersion.insertCue(insertIndex)
            loadShow()
            if let insertedIndex = cues.firstIndex(where: { $0 === newCue }) {
                newCue.createName(insertedIndex + 1)
                selectCue(at: insertedIndex)
            }
            fx.show.save()
        }
    }
    
    func duplicateCue(at index: Int) {
        guard index >= 0 && index < cues.count else { return }
        let original = cues[index]
        let data = NSKeyedArchiver.archivedData(withRootObject: original)
        guard let copy = NSKeyedUnarchiver.unarchiveObject(with: data) as? FxCue else { return }
        
        let insertIndex = index + 1
        if insertIndex >= cues.count {
            _ = fx.show.currentVersion.addCue(copy)
        } else {
            fx.show.currentVersion.cues.insert(copy, at: insertIndex)
        }
        fx.show.save()
        loadShow()
        selectCue(at: insertIndex)
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
        copiedCueData = NSKeyedArchiver.archivedData(withRootObject: original)
        canPaste = true
    }
    
    func pasteCue() {
        guard let data = copiedCueData,
              let copy = NSKeyedUnarchiver.unarchiveObject(with: data) as? FxCue else { return }
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
        
        // Force cue list refresh
        cueListRefreshID += 1
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
        // Populate multi-output selection: primary + any additional outputs
        effectSelectedOutputs = Set([effect.output]).union(effect.additionalOutputs)
        effectOutputVolumes = effect.outputVolumes
        effectDontFade = effect.dontFade
        
        // Sync engine
        cue.currentEffectNo = index
        cue.currentEffect = effect
        
        // Load audio properties
        if effect.type == fx.TYPE_AUDIO || effect.type == fx.TYPE_MUSIC {
            // Get full file duration for trim view
            loadFileDuration(for: effect)
            // Fallback: ensure fileDuration is at least as large as outPoint
            if fileDuration <= 0 && effect.outPoint > 0 {
                fileDuration = effect.outPoint
            }
            // If outPoint is 0 but we have a valid file, default to the track length
            if effect.outPoint <= 0 && !effect.file.isEmpty && fileDuration > 0 {
                effect.outPoint = fileDuration
                outPoint = fileDuration
                fx.show.save()
            }
            let duration = effect.getDuration()
            if duration > 0 {
                effectDuration = duration
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
            updateCueNameFromFirstEffect(cue, effectName: effect.name)
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
                    
                    // Fallback: use AVFoundation if BASS didn't return a valid duration
                    if effect.outPoint <= 0 {
                        let asset = AVURLAsset(url: URL(fileURLWithPath: destPath))
                        let duration = Float(CMTimeGetSeconds(asset.duration))
                        if duration > 0 {
                            effect.outPoint = duration
                        }
                    }
                    
                    cue.addEffect(effect)
                }
                
                // If this was the first effect added, update the cue name
                if cue.effects.count > 0 {
                    self.updateCueNameFromFirstEffect(cue, effectName: cue.effects[0].name)
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
    
    /// Toggle an output bus on/off for the current effect. At least one must remain selected.
    func toggleOutput(_ index: Int) {
        if effectSelectedOutputs.contains(index) {
            // Don't allow deselecting the last one
            if effectSelectedOutputs.count > 1 {
                effectSelectedOutputs.remove(index)
            }
        } else {
            effectSelectedOutputs.insert(index)
        }
        // Update primary output to the lowest selected index
        if let primary = effectSelectedOutputs.sorted().first {
            effectOutput = primary
        }
        saveEffectProperties()
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
        // Sync multi-output: primary output is the lowest selected, rest are additional
        let sorted = effectSelectedOutputs.sorted()
        if let primary = sorted.first {
            effect.output = primary
            effectOutput = primary
            effect.additionalOutputs = Set(sorted.dropFirst())
        } else {
            effect.output = 0
            effectOutput = 0
            effect.additionalOutputs = []
        }
        // Save per-output volume overrides (only for selected outputs)
        effect.outputVolumes = effectOutputVolumes.filter { effectSelectedOutputs.contains($0.key) }
        effect.dontFade = effectDontFade
        
        // Live update if playing
        if effect.isPlaying() {
            // Apply effective volume (level × trim) to primary stream
            let primaryTrim = effect.trimForOutput(effect.output)
            let primaryVol = effectLevel * primaryTrim
            fx.audio.setLevel(effect.stream, level: primaryVol)
            if !settings.logLevels {
                fx.audio.fade(to: effect.stream, fadeTime: 0, level: primaryVol)
            }
            fx.audio.setPan(effect.stream, level: effectPan)
            // Apply effective volume (level × trim) to additional streams
            let sortedAdditional = effect.sortedAdditionalOutputs
            for (i, s) in effect.additionalStreams.enumerated() {
                let trim: Float = (i < sortedAdditional.count) ? effect.trimForOutput(sortedAdditional[i]) : 1.0
                let vol = effectLevel * trim
                fx.audio.setLevel(s, level: vol)
                if !settings.logLevels {
                    fx.audio.fade(to: s, fadeTime: 0, level: vol)
                }
                fx.audio.setPan(s, level: effectPan)
            }
        }
        
        // Update duration
        let duration = effect.getDuration()
        if duration > 0 {
            effectDuration = duration
        }
        
        fx.show.save()
        
        // Force refresh effect list
        objectWillChange.send()
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
                
                // Fallback: use AVFoundation if BASS didn't return a valid duration
                if effect.outPoint <= 0 {
                    let asset = AVURLAsset(url: URL(fileURLWithPath: destPath))
                    let duration = Float(CMTimeGetSeconds(asset.duration))
                    if duration > 0 {
                        effect.outPoint = duration
                    }
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
            effect.stop()
            isPreviewingEffect = false
        } else {
            // Use play(true) to go through execute() which properly applies
            // fade-in, adds to active effects, and sets up state for fade-out
            effect.play(true)
            // If the cursor is positioned beyond the start, seek to that position
            if currentPlaybackPosition > 0 {
                let absolutePosition = effect.inPoint + currentPlaybackPosition
                fx.audio.setPos(effect.stream, position: absolutePosition)
                for s in effect.additionalStreams { fx.audio.setPos(s, position: absolutePosition) }
            }
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
            effect.stop()
            isPreviewingEffect = false
        } else {
            // Load via the same output routing (through the mixer)
            effect.stream = fx.loadOnOutput(documentsPath(effect.file), route: effect.outputRoute, output: effect.output)
            fx.audio.setLevel(effect.stream, level: effect.level)
            fx.audio.setPan(effect.stream, level: effect.pan)
            fx.addEq(effect.stream, eqArray: effect.eq)
            fx.addDsp(effect.stream, dsp: effect.dsp)
            
            // Also load additional output streams
            effect.loadAdditionalStreams(filePath: documentsPath(effect.file))
            for s in effect.additionalStreams {
                fx.audio.setLevel(s, level: effect.level)
                fx.audio.setPan(s, level: effect.pan)
                fx.addEq(s, eqArray: effect.eq)
                fx.addDsp(s, dsp: effect.dsp)
            }
            
            // Set up effect state so process() can handle out-point and fade-out
            effect.fadeIn = false
            effect.fading = false
            effect.startTime = CACurrentMediaTime()
            effect.delayPending = false
            effect.currentVolume = effect.level
            fx.addActive(effect)
            
            fx.audio.play(effect.stream)
            for s in effect.additionalStreams { fx.audio.play(s) }
            // Seek to the current playback position (relative to inPoint)
            let absolutePosition = effect.inPoint + currentPlaybackPosition
            fx.audio.setPos(effect.stream, position: absolutePosition)
            for s in effect.additionalStreams { fx.audio.setPos(s, position: absolutePosition) }
            isPreviewingEffect = true
        }
    }
    
    func seekToPosition(_ position: Float) {
        guard let effect = currentEffect else { return }
        currentPlaybackPosition = position
        
        if effect.isPlaying() {
            let absolutePosition = effect.inPoint + position
            fx.audio.setPos(effect.stream, position: absolutePosition)
            for s in effect.additionalStreams { fx.audio.setPos(s, position: absolutePosition) }
        }
    }
    
    // MARK: - Waveform
    
    private func loadWaveformData(for effect: FxEffect) {
        guard !effect.file.isEmpty else {
            waveformData = []
            hiResWaveformData = []
            return
        }
        let filePath = documentsPath(effect.file)
        let segmentCount = 200
        let hiResCount = 800
        let fromTime = effect.inPoint
        let toTime = effect.outPoint > effect.inPoint ? effect.outPoint : effect.inPoint + 1
        
        DispatchQueue.global(qos: .userInitiated).async {
            let data = fx.getWaveformData(filePath: filePath, segments: segmentCount, fromTime: fromTime, toTime: toTime)
            let hiRes = fx.getWaveformData(filePath: filePath, segments: hiResCount, fromTime: fromTime, toTime: toTime)
            DispatchQueue.main.async { [weak self] in
                self?.waveformData = data
                self?.hiResWaveformData = hiRes
            }
        }
    }
    
    /// Load full-file waveform data (not trimmed) for the overview trim view
    private func loadFullWaveformData(for effect: FxEffect) {
        guard !effect.file.isEmpty else {
            fullWaveformData = []
            hiResFullWaveformData = []
            return
        }
        let filePath = documentsPath(effect.file)
        let segmentCount = 200
        let hiResCount = 800  // Higher resolution for zoomed view
        
        DispatchQueue.global(qos: .userInitiated).async {
            let data = fx.getWaveformData(filePath: filePath, segments: segmentCount)
            let hiRes = fx.getWaveformData(filePath: filePath, segments: hiResCount)
            DispatchQueue.main.async { [weak self] in
                self?.fullWaveformData = data
                self?.hiResFullWaveformData = hiRes
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
    
    /// Auto-trim silence from start and end of the clip using the engine's silence detection
    func autoTrimSilence() {
        guard let effect = currentEffect, !effect.file.isEmpty, fileDuration > 0 else { return }
        let filePath = documentsPath(effect.file)
        
        var trimIn: Float = 0
        var trimOut: Float = 0
        fx.audio.getTrim(filePath, inPoint: &trimIn, outPont: &trimOut)
        
        // Only apply if we got valid results
        if trimIn >= 0 && trimIn < fileDuration {
            inPoint = trimIn
            effect.inPoint = trimIn
        }
        if trimOut > inPoint && trimOut <= fileDuration {
            outPoint = trimOut
            effect.outPoint = trimOut
        }
        
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
    
    // MARK: - Zoom Controls
    
    /// Zoom in on the trim waveform (full file view)
    func zoomInTrimView() {
        trimZoomLevel = min(trimZoomLevel * 1.5, 20.0)
    }
    
    /// Zoom out on the trim waveform
    func zoomOutTrimView() {
        trimZoomLevel = max(trimZoomLevel / 1.5, 1.0)
        if trimZoomLevel <= 1.0 { trimScrollOffset = 0 }
    }
    
    /// Reset trim view zoom to fit
    func resetTrimZoom() {
        trimZoomLevel = 1.0
        trimScrollOffset = 0
    }
    
    /// Zoom in on the playback timeline
    func zoomInTimeline() {
        timelineZoomLevel = min(timelineZoomLevel * 1.5, 20.0)
    }
    
    /// Zoom out on the playback timeline
    func zoomOutTimeline() {
        timelineZoomLevel = max(timelineZoomLevel / 1.5, 1.0)
        if timelineZoomLevel <= 1.0 { timelineScrollOffset = 0 }
    }
    
    /// Reset timeline zoom to fit
    func resetTimelineZoom() {
        timelineZoomLevel = 1.0
        timelineScrollOffset = 0
    }
    
    /// Zoom trim view to fit the trimmed region (in point to out point)
    func zoomToTrimRegion() {
        guard fileDuration > 0 else { return }
        let trimFraction = CGFloat((outPoint - inPoint) / fileDuration)
        guard trimFraction > 0 else { return }
        // Zoom so trim fills ~80% of viewport
        trimZoomLevel = min(0.8 / trimFraction, 20.0)
        // Set scroll target as fraction of file — view will convert to pixels
        let inFraction = CGFloat(inPoint / fileDuration)
        let margin: CGFloat = 0.02
        trimScrollTargetFraction = max(0, inFraction - margin)
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
    
    /// When adding the first effect to a cue, set the cue name from the effect name
    /// if the cue still has the default name format (e.g. "Cue:1>" or "Cue:1> Silence")
    private func updateCueNameFromFirstEffect(_ cue: FxCue, effectName: String) {
        guard cue.effects.count == 1, !effectName.isEmpty else { return }
        // Default names end with ">" or "> Silence"
        let name = cue.name.trimmingCharacters(in: .whitespaces)
        if name.hasSuffix(">") || name.hasSuffix("> Silence") {
            let prefix = name.components(separatedBy: ">").first ?? ""
            cue.name = "\(prefix)> \(effectName)"
            cueName = cue.name
            cueListRefreshID += 1
        }
    }
    
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
        effectSelectedOutputs = [0]
        effectOutputVolumes = [:]
        effectDontFade = false
        effectDuration = 0
        fileDuration = 0
        currentPlaybackPosition = 0
        waveformData = []
        fullWaveformData = []
        hiResFullWaveformData = []
        hiResWaveformData = []
        isPreviewingEffect = false
        trimZoomLevel = 1.0
        trimScrollOffset = 0
        trimScrollTargetFraction = nil
        timelineZoomLevel = 1.0
        timelineScrollOffset = 0
    }
}
