//
//  MacDesignView.swift
//  FX-Live-Mac
//
//  Native macOS Design screen for cue and effect editing
//

import SwiftUI
import UniformTypeIdentifiers

struct MacDesignView: View {
    @StateObject private var viewModel = MacDesignViewModel()
    
    var body: some View {
        HSplitView {
            // Left: Cue list
            VStack(spacing: 0) {
                HStack {
                    Text("CUES")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: { viewModel.addCue() }) {
                        Image(systemName: "plus")
                    }
                    Button(action: { viewModel.copyCue() }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(viewModel.selectedCueIndex == nil)
                    Button(action: { viewModel.deleteCue() }) {
                        Image(systemName: "trash")
                    }
                    .disabled(viewModel.selectedCueIndex == nil)
                }
                .padding()
                
                Divider()
                
                List(Array(viewModel.cues.enumerated()), id: \.offset) { index, cue in
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 30)
                        VStack(alignment: .leading) {
                            Text(cue.getName())
                                .font(.body)
                                .fontWeight(viewModel.selectedCueIndex == index ? .bold : .regular)
                            HStack {
                                Text("\(cue.totalEffects()) effects")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if cue.autoFollow {
                                    Text("Auto")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        Spacer()
                        Text(formatSeconds(cue.duration()))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(
                        viewModel.selectedCueIndex == index ? Color.accentColor.opacity(0.2) : Color.clear
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectCue(at: index)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                
                // Cue reorder buttons
                HStack {
                    Button(action: { viewModel.moveCueUp() }) {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(viewModel.selectedCueIndex == nil || viewModel.selectedCueIndex == 0)
                    
                    Button(action: { viewModel.moveCueDown() }) {
                        Image(systemName: "arrow.down")
                    }
                    .disabled(viewModel.selectedCueIndex == nil || viewModel.selectedCueIndex == (viewModel.cues.count - 1))
                    
                    Spacer()
                    
                    Button("Renumber") { viewModel.renumberCues() }
                        .font(.caption)
                }
                .padding(8)
            }
            .frame(minWidth: 220, maxWidth: 300)
            
            // Center: Cue properties + Effects
            VStack(spacing: 0) {
                if let cueIndex = viewModel.selectedCueIndex,
                   cueIndex < viewModel.cues.count {
                    
                    // Cue properties
                    GroupBox("Cue Properties") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Name:")
                                    .frame(width: 60, alignment: .trailing)
                                TextField("Cue Name", text: $viewModel.cueName)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit { viewModel.saveCueProperties() }
                            }
                            
                            HStack {
                                Text("Notes:")
                                    .frame(width: 60, alignment: .trailing)
                                TextField("Cue Notes", text: $viewModel.cueNotes)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit { viewModel.saveCueProperties() }
                            }
                            
                            HStack {
                                Toggle("Auto Follow", isOn: $viewModel.autoFollow)
                                    .onChange(of: viewModel.autoFollow) { _, _ in viewModel.saveCueProperties() }
                                
                                if viewModel.autoFollow {
                                    Text("Delay:")
                                    TextField("", value: $viewModel.autoFollowDelay, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                        .onSubmit { viewModel.saveCueProperties() }
                                    Text("s")
                                    
                                    Toggle("At End", isOn: $viewModel.autoFollowEnd)
                                        .onChange(of: viewModel.autoFollowEnd) { _, _ in viewModel.saveCueProperties() }
                                }
                            }
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Effects list
                    GroupBox("Effects") {
                        VStack(spacing: 0) {
                            HStack {
                                Button(action: { viewModel.addEffect() }) {
                                    Label("Add Effect", systemImage: "plus")
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: { viewModel.deleteEffect() }) {
                                    Label("Remove", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .disabled(viewModel.selectedEffectIndex == nil)
                                
                                Spacer()
                                
                                Button(action: { viewModel.moveEffectUp() }) {
                                    Image(systemName: "arrow.up")
                                }
                                .disabled(viewModel.selectedEffectIndex == nil || viewModel.selectedEffectIndex == 0)
                                
                                Button(action: { viewModel.moveEffectDown() }) {
                                    Image(systemName: "arrow.down")
                                }
                                .disabled(viewModel.selectedEffectIndex == nil)
                            }
                            .padding(8)
                            
                            let cue = viewModel.cues[cueIndex]
                            if cue.effects.count == 0 {
                                VStack {
                                    Spacer()
                                    Image(systemName: "waveform.badge.plus")
                                        .font(.system(size: 36))
                                        .foregroundColor(.secondary)
                                    Text("No effects in this cue")
                                        .foregroundColor(.secondary)
                                    Text("Click Add Effect to browse audio files")
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.7))
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, minHeight: 150)
                            } else {
                                List(Array(cue.effects.enumerated()), id: \.offset) { index, effect in
                                    HStack {
                                        Image(systemName: iconForType(effect.type))
                                            .foregroundColor(.blue)
                                            .frame(width: 20)
                                        VStack(alignment: .leading) {
                                            Text(effect.name)
                                                .font(.body)
                                                .fontWeight(viewModel.selectedEffectIndex == index ? .bold : .regular)
                                            Text(effect.file.isEmpty ? "No file" : effect.file)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        if effect.loop {
                                            Image(systemName: "repeat")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                        if effect.background {
                                            Image(systemName: "arrow.right.circle")
                                                .font(.caption)
                                                .foregroundColor(.purple)
                                        }
                                        Text(String(format: "%.0f%%", effect.level * 100))
                                            .font(.caption.monospacedDigit())
                                            .frame(width: 40)
                                    }
                                    .listRowBackground(
                                        viewModel.selectedEffectIndex == index ? Color.accentColor.opacity(0.2) : Color.clear
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.selectEffect(at: index)
                                    }
                                }
                                .listStyle(.inset(alternatesRowBackgrounds: true))
                                .frame(minHeight: 150)
                            }
                            
                            // Spot Effects
                            Divider()
                            HStack {
                                Text("Spot Effects")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: { viewModel.addSpotEffect() }) {
                                    Label("Add Spot", systemImage: "plus")
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                            .padding(8)
                            
                            if cue.spotEffects.count > 0 {
                                ForEach(Array(cue.spotEffects.enumerated()), id: \.offset) { index, spot in
                                    HStack {
                                        Image(systemName: "bolt.fill")
                                            .foregroundColor(.yellow)
                                        Text(spot.name.isEmpty ? "Spot \(index + 1)" : spot.name)
                                            .font(.caption)
                                        Spacer()
                                        Button(action: { viewModel.deleteSpotEffect(at: index) }) {
                                            Image(systemName: "xmark.circle")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                } else {
                    VStack {
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
            .frame(minWidth: 400)
            
            // Right: Effect properties (when selected)
            if viewModel.selectedEffectIndex != nil {
                ScrollView {
                    VStack(spacing: 16) {
                        GroupBox("Effect Properties") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Name:")
                                        .frame(width: 70, alignment: .trailing)
                                    TextField("Effect Name", text: $viewModel.effectName)
                                        .textFieldStyle(.roundedBorder)
                                        .onSubmit { viewModel.saveEffectProperties() }
                                }
                                
                                HStack {
                                    Text("File:")
                                        .frame(width: 70, alignment: .trailing)
                                    Text(viewModel.effectFile.isEmpty ? "No file selected" : viewModel.effectFile)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                    Button("Browse...") { viewModel.browseForFile() }
                                        .buttonStyle(.bordered)
                                }
                                
                                Divider()
                                
                                HStack {
                                    Text("Volume:")
                                        .frame(width: 70, alignment: .trailing)
                                    Slider(value: $viewModel.effectLevel, in: 0...2)
                                        .onChange(of: viewModel.effectLevel) { _, _ in viewModel.saveEffectProperties() }
                                    Text(String(format: "%.0f%%", viewModel.effectLevel * 100))
                                        .font(.body.monospacedDigit())
                                        .frame(width: 50)
                                }
                                
                                HStack {
                                    Text("Pan:")
                                        .frame(width: 70, alignment: .trailing)
                                    Slider(value: $viewModel.effectPan, in: -1...1)
                                        .onChange(of: viewModel.effectPan) { _, _ in viewModel.saveEffectProperties() }
                                    Text(viewModel.effectPan == 0 ? "C" :
                                         viewModel.effectPan < 0 ? String(format: "L%.0f", abs(viewModel.effectPan) * 100) :
                                         String(format: "R%.0f", viewModel.effectPan * 100))
                                        .font(.body.monospacedDigit())
                                        .frame(width: 50)
                                }
                                
                                Divider()
                                
                                HStack {
                                    Text("Fade In:")
                                        .frame(width: 70, alignment: .trailing)
                                    TextField("", value: $viewModel.fadeIn, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                        .onSubmit { viewModel.saveEffectProperties() }
                                    Text("s")
                                    
                                    Spacer()
                                    
                                    Text("Fade Out:")
                                    TextField("", value: $viewModel.fadeOut, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                        .onSubmit { viewModel.saveEffectProperties() }
                                    Text("s")
                                }
                                
                                HStack {
                                    Text("Delay:")
                                        .frame(width: 70, alignment: .trailing)
                                    TextField("", value: $viewModel.effectDelay, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                        .onSubmit { viewModel.saveEffectProperties() }
                                    Text("s")
                                }
                                
                                Divider()
                                
                                HStack {
                                    Text("In Point:")
                                        .frame(width: 70, alignment: .trailing)
                                    TextField("", value: $viewModel.inPoint, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                        .onSubmit { viewModel.saveEffectProperties() }
                                    Text("s")
                                    
                                    Spacer()
                                    
                                    Text("Out:")
                                    TextField("", value: $viewModel.outPoint, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                        .onSubmit { viewModel.saveEffectProperties() }
                                    Text("s")
                                }
                                
                                Divider()
                                
                                Toggle("Loop", isOn: $viewModel.effectLoop)
                                    .onChange(of: viewModel.effectLoop) { _, _ in viewModel.saveEffectProperties() }
                                Toggle("Background (continues after GO)", isOn: $viewModel.effectBackground)
                                    .onChange(of: viewModel.effectBackground) { _, _ in viewModel.saveEffectProperties() }
                            }
                            .padding(8)
                        }
                        
                        // Preview
                        GroupBox("Preview") {
                            HStack {
                                Button(action: { viewModel.previewPlay() }) {
                                    Image(systemName: "play.fill")
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: { viewModel.previewPause() }) {
                                    Image(systemName: "pause.fill")
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: { viewModel.previewStop() }) {
                                    Image(systemName: "stop.fill")
                                }
                                .buttonStyle(.bordered)
                                
                                Spacer()
                                
                                Text(viewModel.previewTime)
                                    .font(.body.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                        }
                    }
                    .padding()
                }
                .frame(width: 320)
            }
        }
        .onAppear {
            viewModel.loadShow()
        }
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case fx.TYPE_AUDIO: return "waveform"
        case fx.TYPE_MUSIC: return "music.note"
        case fx.TYPE_MIDI: return "pianokeys"
        case fx.TYPE_IMAGE: return "photo"
        case fx.TYPE_VIDEO: return "film"
        default: return "questionmark"
        }
    }
}

// MARK: - View Model

@MainActor
class MacDesignViewModel: ObservableObject {
    @Published var cues: [FxCue] = []
    @Published var selectedCueIndex: Int?
    @Published var selectedEffectIndex: Int?
    
    @Published var cueName = ""
    @Published var cueNotes = ""
    @Published var autoFollow = false
    @Published var autoFollowDelay: Float = 0
    @Published var autoFollowEnd = false
    
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
    @Published var previewTime = "00:00"
    
    private var previewTimer: Timer?
    
    func loadShow() {
        cues = fx.show.currentVersion.cues
    }
    
    func selectCue(at index: Int) {
        selectedCueIndex = index
        selectedEffectIndex = nil
        let cue = cues[index]
        cueName = cue.getName()
        cueNotes = cue.notes
        autoFollow = cue.autoFollow
        autoFollowDelay = cue.autoFollowDelay
        autoFollowEnd = cue.autoFollowEnd
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
    }
    
    func selectEffect(at index: Int) {
        guard let cueIndex = selectedCueIndex, cueIndex < cues.count else { return }
        let cue = cues[cueIndex]
        guard index < cue.effects.count else { return }
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
        
        // Load preview
        if !effect.file.isEmpty {
            let path = documentsPath(effect.file)
            fx.loadPreview(path)
            startPreviewTimer()
        }
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
        fx.show.save()
    }
    
    func addCue() {
        _ = fx.show.currentVersion.addCue(FxCue())
        fx.show.save()
        loadShow()
        selectCue(at: cues.count - 1)
    }
    
    func copyCue() {
        guard let index = selectedCueIndex, index < cues.count else { return }
        let original = cues[index]
        // Archive and unarchive to create a deep copy
        let data = NSKeyedArchiver.archivedData(withRootObject: original)
        if let copy = NSKeyedUnarchiver.unarchiveObject(with: data) as? FxCue {
            copy.name = "\(original.getName()) (copy)"
            _ = fx.show.currentVersion.addCue(copy)
            fx.show.save()
            loadShow()
            selectCue(at: cues.count - 1)
        }
    }
    
    func deleteCue() {
        guard let index = selectedCueIndex, index < cues.count else { return }
        fx.show.currentVersion.cues.remove(at: index)
        fx.show.save()
        selectedCueIndex = nil
        selectedEffectIndex = nil
        loadShow()
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
            cue.name = "Cue \(i + 1)"
        }
        fx.show.save()
        loadShow()
    }
    
    func addEffect() {
        guard let cueIndex = selectedCueIndex, cueIndex < cues.count else { return }
        
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio, .mpeg4Audio, .mp3, .wav, .aiff]
        panel.title = "Select Audio File"
        
        // Start in Documents directory
        let docsURL = URL(fileURLWithPath: documentsPath())
        panel.directoryURL = docsURL
        
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            DispatchQueue.main.async {
                for url in panel.urls {
                    // Copy file to documents if not already there
                    let fileName = url.lastPathComponent
                    let destPath = documentsPath(fileName)
                    
                    if !FileManager.default.fileExists(atPath: destPath) {
                        try? FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destPath))
                    }
                    
                    let effect = FxEffect()
                    effect.name = (fileName as NSString).deletingPathExtension
                    effect.file = fileName
                    effect.type = fx.TYPE_AUDIO
                    
                    // Get duration for out point
                    let stream = fx.audio.loadPreview(destPath)
                    if stream > 0 {
                        effect.outPoint = Float(fx.audio.getDur(stream))
                        fx.audio.stop(stream)
                    }
                    
                    let cue = fx.show.currentVersion.cues[cueIndex]
                    cue.addEffect(effect)
                }
                fx.show.save()
                self?.loadShow()
                if let cueIdx = self?.selectedCueIndex {
                    self?.selectCue(at: cueIdx)
                }
            }
        }
    }
    
    func addSpotEffect() {
        guard let cueIndex = selectedCueIndex, cueIndex < cues.count else { return }
        
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio, .mpeg4Audio, .mp3, .wav, .aiff]
        panel.title = "Select Spot Effect Audio"
        panel.directoryURL = URL(fileURLWithPath: documentsPath())
        
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            DispatchQueue.main.async {
                let fileName = url.lastPathComponent
                let destPath = documentsPath(fileName)
                
                if !FileManager.default.fileExists(atPath: destPath) {
                    try? FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destPath))
                }
                
                let effect = FxEffect()
                effect.name = (fileName as NSString).deletingPathExtension
                effect.file = fileName
                effect.type = fx.TYPE_AUDIO
                
                let stream = fx.audio.loadPreview(destPath)
                if stream > 0 {
                    effect.outPoint = Float(fx.audio.getDur(stream))
                    fx.audio.stop(stream)
                }
                
                let cue = fx.show.currentVersion.cues[cueIndex]
                cue.spotEffects.append(effect)
                fx.show.save()
                self?.loadShow()
                if let idx = self?.selectedCueIndex {
                    self?.selectCue(at: idx)
                }
            }
        }
    }
    
    func deleteEffect() {
        guard let cueIndex = selectedCueIndex, cueIndex < cues.count,
              let effectIndex = selectedEffectIndex else { return }
        let cue = cues[cueIndex]
        guard effectIndex < cue.effects.count else { return }
        cue.effects.remove(at: effectIndex)
        fx.show.save()
        selectedEffectIndex = nil
        loadShow()
    }
    
    func deleteSpotEffect(at index: Int) {
        guard let cueIndex = selectedCueIndex, cueIndex < cues.count else { return }
        let cue = cues[cueIndex]
        guard index < cue.spotEffects.count else { return }
        cue.spotEffects.remove(at: index)
        fx.show.save()
        loadShow()
    }
    
    func moveEffectUp() {
        guard let cueIndex = selectedCueIndex, cueIndex < cues.count,
              let effectIndex = selectedEffectIndex, effectIndex > 0 else { return }
        let cue = cues[cueIndex]
        cue.effects.swapAt(effectIndex, effectIndex - 1)
        selectedEffectIndex = effectIndex - 1
        fx.show.save()
        loadShow()
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
                let fileName = url.lastPathComponent
                let destPath = documentsPath(fileName)
                
                if !FileManager.default.fileExists(atPath: destPath) {
                    try? FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destPath))
                }
                
                let cue = fx.show.currentVersion.cues[cueIndex]
                let effect = cue.effects[effectIndex]
                effect.file = fileName
                if effect.name.isEmpty {
                    effect.name = (fileName as NSString).deletingPathExtension
                }
                
                let stream = fx.audio.loadPreview(destPath)
                if stream > 0 {
                    effect.outPoint = Float(fx.audio.getDur(stream))
                }
                
                self?.effectFile = fileName
                self?.outPoint = effect.outPoint
                fx.show.save()
                
                fx.loadPreview(destPath)
                self?.startPreviewTimer()
            }
        }
    }
    
    // Preview controls
    func previewPlay() { fx.playPreview() }
    func previewPause() { fx.pausePreview() }
    func previewStop() { fx.stopPreview() }
    
    private func startPreviewTimer() {
        previewTimer?.invalidate()
        previewTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.previewTime = fx.getPreviewProgress()
            }
        }
    }
}
