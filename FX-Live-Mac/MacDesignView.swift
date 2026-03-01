//
//  MacDesignView.swift
//  FX-Live-Mac
//
//  Native macOS Design screen for cue and effect editing
//

import SwiftUI

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
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 30)
                        VStack(alignment: .leading) {
                            Text(cue.getName())
                                .font(.body)
                            Text("\(cue.totalEffects()) effects")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .listRowBackground(
                        viewModel.selectedCueIndex == index ? Color.accentColor.opacity(0.2) : Color.clear
                    )
                    .onTapGesture {
                        viewModel.selectCue(at: index)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
            .frame(minWidth: 220, maxWidth: 300)
            
            // Center: Cue properties
            VStack(spacing: 16) {
                if let cueIndex = viewModel.selectedCueIndex,
                   cueIndex < viewModel.cues.count {
                    let cue = viewModel.cues[cueIndex]
                    
                    // Cue name
                    GroupBox("Cue Properties") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Name:")
                                TextField("Cue Name", text: $viewModel.cueName)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack {
                                Text("Notes:")
                                TextField("Cue Notes", text: $viewModel.cueNotes)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            Toggle("Auto Follow", isOn: $viewModel.autoFollow)
                            
                            if viewModel.autoFollow {
                                HStack {
                                    Text("Delay:")
                                    TextField("Seconds", value: $viewModel.autoFollowDelay, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                    Text("seconds")
                                }
                            }
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)
                    
                    // Effects list
                    GroupBox("Effects") {
                        VStack(spacing: 0) {
                            HStack {
                                Spacer()
                                Button(action: { viewModel.addEffect() }) {
                                    Label("Add Effect", systemImage: "plus")
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(8)
                            
                            if cue.effects.count == 0 {
                                VStack {
                                    Spacer()
                                    Text("No effects in this cue")
                                        .foregroundColor(.secondary)
                                    Text("Click Add Effect to browse audio files")
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.7))
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                            } else {
                                List(Array(cue.effects.enumerated()), id: \.offset) { index, effect in
                                    HStack {
                                        Image(systemName: iconForType(effect.type))
                                            .foregroundColor(.blue)
                                        VStack(alignment: .leading) {
                                            Text(effect.name)
                                                .font(.body)
                                            Text(effect.file)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text(String(format: "%.0f%%", effect.level * 100))
                                            .font(.caption.monospacedDigit())
                                    }
                                    .onTapGesture {
                                        viewModel.selectEffect(at: index)
                                    }
                                }
                                .listStyle(.inset(alternatesRowBackgrounds: true))
                                .frame(minHeight: 200)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
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
                VStack(spacing: 16) {
                    GroupBox("Effect Properties") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Name:")
                                TextField("Effect Name", text: $viewModel.effectName)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack {
                                Text("Volume:")
                                Slider(value: $viewModel.effectLevel, in: 0...2)
                                Text(String(format: "%.0f%%", viewModel.effectLevel * 100))
                                    .frame(width: 50)
                            }
                            
                            HStack {
                                Text("Pan:")
                                Slider(value: $viewModel.effectPan, in: -1...1)
                                Text(viewModel.effectPan == 0 ? "C" :
                                     viewModel.effectPan < 0 ? String(format: "L%.0f", abs(viewModel.effectPan) * 100) :
                                     String(format: "R%.0f", viewModel.effectPan * 100))
                                    .frame(width: 50)
                            }
                            
                            HStack {
                                Text("Fade In:")
                                TextField("", value: $viewModel.fadeIn, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                Text("s")
                                
                                Text("Fade Out:")
                                TextField("", value: $viewModel.fadeOut, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                Text("s")
                            }
                            
                            Toggle("Loop", isOn: $viewModel.effectLoop)
                            Toggle("Background", isOn: $viewModel.effectBackground)
                        }
                        .padding(8)
                    }
                    
                    Spacer()
                }
                .frame(width: 300)
                .padding()
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
    
    @Published var effectName = ""
    @Published var effectLevel: Float = 1.0
    @Published var effectPan: Float = 0
    @Published var fadeIn: Float = 0
    @Published var fadeOut: Float = 0
    @Published var effectLoop = false
    @Published var effectBackground = false
    
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
    }
    
    func selectEffect(at index: Int) {
        guard let cueIndex = selectedCueIndex, cueIndex < cues.count else { return }
        let cue = cues[cueIndex]
        guard index < cue.effects.count else { return }
        selectedEffectIndex = index
        let effect = cue.effects[index]
        effectName = effect.name
        effectLevel = effect.level
        effectPan = effect.pan
        fadeIn = effect.inTrans
        fadeOut = effect.outTrans
        effectLoop = effect.loop
        effectBackground = effect.background
    }
    
    func addCue() {
        _ = fx.show.currentVersion.addCue(FxCue())
        fx.show.save()
        loadShow()
    }
    
    func deleteCue() {
        guard selectedCueIndex != nil else { return }
        fx.show.currentVersion.deleteCue()
        fx.show.save()
        selectedCueIndex = nil
        loadShow()
    }
    
    func addEffect() {
        // TODO: Open file browser to select audio file
    }
}
