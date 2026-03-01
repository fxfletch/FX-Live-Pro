//
//  MacPerformView.swift
//  FX-Live-Mac
//
//  Native macOS Perform screen with keyboard shortcuts and larger layout
//

import SwiftUI

struct MacPerformView: View {
    @StateObject private var viewModel = MacPerformViewModel()
    
    var body: some View {
        HSplitView {
            // Left: Cue list
            VStack(spacing: 0) {
                // Current Cue
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT CUE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                    Text(viewModel.currentCueName)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.green))
                .padding(8)
                
                // Next Cue
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEXT CUE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.black.opacity(0.6))
                    Text(viewModel.nextCueName)
                        .font(.title3)
                        .foregroundColor(.black)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.yellow.opacity(0.7)))
                .padding(.horizontal, 8)
                
                // Cue Notes
                VStack(alignment: .leading, spacing: 4) {
                    Text("NOTES")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(viewModel.currentCueNotes.isEmpty ? "No notes" : viewModel.currentCueNotes)
                        .font(.body)
                        .foregroundColor(viewModel.currentCueNotes.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .padding(.horizontal, 8)
                
                Divider()
                
                // Cue List
                List(Array(viewModel.cues.enumerated()), id: \.offset) { index, cue in
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cue.getName())
                                .font(.body)
                                .fontWeight(viewModel.isActiveCue(index) ? .bold : .regular)
                            
                            HStack {
                                Text(viewModel.formatSeconds(cue.duration()))
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
                    }
                    .listRowBackground(
                        viewModel.isActiveCue(index) ? Color.green.opacity(0.3) :
                        viewModel.isNextCue(index) ? Color.yellow.opacity(0.3) :
                        Color.clear
                    )
                    .onTapGesture {
                        viewModel.selectCue(at: index)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
            .frame(minWidth: 280, maxWidth: 400)
            
            // Right: Controls and active effects
            VStack(spacing: 16) {
                // GO Button
                Button(action: { viewModel.go() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 28))
                        Text("GO")
                            .font(.system(size: 36, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.isAutoFollowActive ? Color.red : Color.green)
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
                .padding(.horizontal)
                
                // Transport Controls
                HStack(spacing: 12) {
                    Button("Stop") { viewModel.stopAll() }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .keyboardShortcut("s", modifiers: [])
                    
                    Button(viewModel.isPaused ? "Resume" : "Pause") { viewModel.pauseAll() }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .keyboardShortcut("p", modifiers: [])
                    
                    Button(viewModel.isPaused ? "Back 10s" : "Abort") { viewModel.abortCue() }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                        .keyboardShortcut("a", modifiers: [])
                    
                    Button("Recue Show") { viewModel.recueShow() }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        .keyboardShortcut("r", modifiers: [])
                }
                .padding(.horizontal)
                
                // Master Volume
                HStack {
                    Text("Master Volume")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $viewModel.masterVolume, in: 0...1)
                    Text("\(Int(viewModel.masterVolume * 100))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 40)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Active Effects
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACTIVE EFFECTS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    if viewModel.activeEffects.isEmpty {
                        VStack {
                            Spacer()
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No active effects")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(viewModel.activeEffects, id: \.id) { effect in
                            MacActiveEffectRow(effect: effect, onStop: {
                                effect.stop()
                            })
                        }
                        .listStyle(.inset(alternatesRowBackgrounds: true))
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadShow()
        }
    }
}

// MARK: - Active Effect Row

struct MacActiveEffectRow: View {
    let effect: FxEffect
    let onStop: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(effect.name)
                    .font(.body)
                Text(effect.status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(effect.getCounter())
                .font(.body.monospacedDigit())
            
            Slider(value: Binding(
                get: { Double(effect.currentVolume) },
                set: { effect.currentVolume = Float($0)
                    fx.audio.setLevel(effect.stream, level: Float($0))
                }
            ), in: 0...2)
            .frame(width: 120)
            
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Model

@MainActor
class MacPerformViewModel: ObservableObject {
    @Published var cues: [FxCue] = []
    @Published var activeEffects: [FxEffect] = []
    @Published var currentCueName = ""
    @Published var currentCueNotes = ""
    @Published var nextCueName = ""
    @Published var activeCueIndex: Int?
    @Published var nextCueIndex: Int?
    @Published var masterVolume: Double = 1.0 {
        didSet { fx.audio.globalVolume(Float(masterVolume)) }
    }
    @Published var isPaused = false
    @Published var isAutoFollowActive = false
    @Published var autoFollowCountdown = ""
    
    private var timer: Timer?
    
    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDisplay()
            }
        }
    }
    
    deinit { timer?.invalidate() }
    
    func loadShow() { updateDisplay() }
    
    func updateDisplay() {
        cues = fx.show.currentVersion.cues
        activeEffects = fx.activeEffects
        
        for eff in fx.activeEffects { eff.process() }
        _ = fx.show.processMusic()
        
        if fx.show.currentVersion.activeCueNo >= 0 && fx.show.currentVersion.activeCueNo < cues.count {
            let currentCue = fx.show.currentVersion.getCue(fx.show.currentVersion.activeCueNo)
            currentCueName = currentCue.getName()
            activeCueIndex = fx.show.currentVersion.activeCueNo
        }
        
        if fx.show.currentVersion.nextCueNo >= 0 && fx.show.currentVersion.nextCueNo < cues.count {
            let nextCue = fx.show.currentVersion.getCue(fx.show.currentVersion.nextCueNo)
            nextCueName = nextCue.getName()
            currentCueNotes = nextCue.notes
            nextCueIndex = fx.show.currentVersion.nextCueNo
        }
        
        isPaused = fx.paused
    }
    
    func formatSeconds(_ seconds: Float) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    func isActiveCue(_ index: Int) -> Bool { index == activeCueIndex }
    func isNextCue(_ index: Int) -> Bool { index == nextCueIndex }
    func selectCue(at index: Int) {
        fx.show.currentVersion.nextCueNo = index
        updateDisplay()
    }
    
    func go() {
        fx.show.currentVersion.Go()
        updateDisplay()
    }
    
    func pauseAll() {
        fx.livePause()
        isPaused = fx.paused
    }
    
    func stopAll() {
        fx.paused = false
        fx.liveStop()
        fx.autoFollowActive = false
        isAutoFollowActive = false
        updateDisplay()
    }
    
    func abortCue() {
        if fx.paused {
            fx.show.currentVersion.jogBack(10)
        } else {
            fx.show.currentVersion.Abort()
            fx.show.currentVersion.nextCueNo = fx.show.currentVersion.activeCueNo
            fx.autoFollowActive = false
            isAutoFollowActive = false
        }
        updateDisplay()
    }
    
    func recueShow() {
        if fx.paused {
            fx.show.currentVersion.jogBack(30)
        } else {
            fx.liveStop()
            fx.show.currentVersion.nextCueNo = 0
            fx.autoFollowActive = false
            isAutoFollowActive = false
        }
        updateDisplay()
    }
}
