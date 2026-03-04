//
//  MacPerformView.swift
//  FX-Live-Mac
//
//  Native macOS Perform screen with keyboard shortcuts, auto-follow, spot effects
//

import SwiftUI

struct MacPerformView: View {
    @StateObject private var viewModel = MacPerformViewModel()
    
    var body: some View {
        HSplitView {
            // Left: Cue list + info
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
                    ScrollView {
                        Text(viewModel.currentCueNotes.isEmpty ? "No notes" : viewModel.currentCueNotes)
                            .font(.body)
                            .foregroundColor(viewModel.currentCueNotes.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                }
                .padding(12)
                .padding(.horizontal, 8)
                
                Divider()
                
                // Cue List
                ScrollViewReader { proxy in
                    List(Array(viewModel.cues.enumerated()), id: \.offset) { index, cue in
                        HStack {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cue.getName())
                                    .font(.body)
                                    .fontWeight(viewModel.isActiveCue(index) ? .bold : .regular)
                                
                                HStack {
                                    Text(viewModel.formatDuration(cue.duration()))
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectCue(at: index)
                        }
                        .id(index)
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .onReceive(viewModel.$activeCueIndex) { newIndex in
                        if let idx = newIndex, idx >= 0 {
                            withAnimation { proxy.scrollTo(idx, anchor: .center) }
                        }
                    }
                }
            }
            .frame(minWidth: 280, maxWidth: 400)
            
            // Right: Controls and active effects
            VStack(spacing: 12) {
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
                
                // Auto-follow countdown
                if viewModel.isAutoFollowActive {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.red)
                        Text(viewModel.autoFollowCountdown)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                        Text("Auto-follow active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.1)))
                    .padding(.horizontal)
                }
                
                // Spot Effects (if current cue has them)
                if !viewModel.spotEffects.isEmpty {
                    GroupBox("Spot Effects") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(Array(viewModel.spotEffects.enumerated()), id: \.offset) { index, effect in
                                Button(action: { viewModel.playSpotEffect(at: index) }) {
                                    Text(effect.name)
                                        .font(.caption)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.7)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(4)
                    }
                    .padding(.horizontal)
                }
                
                // Transport Controls
                HStack(spacing: 12) {
                    Button(action: { viewModel.stopAll() }) {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .keyboardShortcut("s", modifiers: [])
                    
                    Button(action: { viewModel.pauseAll() }) {
                        Label(viewModel.isPaused ? "Resume" : "Pause",
                              systemImage: viewModel.isPaused ? "play.fill" : "pause.fill")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .keyboardShortcut("p", modifiers: [])
                    
                    Button(action: { viewModel.abortCue() }) {
                        Label(viewModel.isPaused ? "Back 10s" : "Abort",
                              systemImage: viewModel.isPaused ? "gobackward.10" : "xmark.circle.fill")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.isPaused ? .purple : .red)
                    .keyboardShortcut("a", modifiers: [])
                    
                    Button(action: { viewModel.recueShow() }) {
                        Label(viewModel.isPaused ? "Back 30s" : "Recue Show",
                              systemImage: viewModel.isPaused ? "gobackward.30" : "arrow.counterclockwise")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .keyboardShortcut("r", modifiers: [])
                }
                .padding(.horizontal)
                
                // Master Volume
                VStack(spacing: 4) {
                    HStack {
                        Text("Master Volume")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(masterVolumeDB(viewModel.masterVolume))
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(viewModel.masterVolume > 0.5 ? .orange : .primary)
                            .frame(width: 70, alignment: .trailing)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $viewModel.masterVolume, in: 0...1)
                            .tint(viewModel.masterVolume > 0.5 ? .orange : .blue)
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    // dB scale markers
                    HStack {
                        Text("-∞")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("0 dB")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("+6 dB")
                            .font(.system(size: 9))
                            .foregroundColor(.orange.opacity(0.7))
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Active Effects
                VStack(alignment: .leading, spacing: 4) {
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
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(viewModel.activeEffects, id: \.id) { effect in
                                    MacActiveEffectRow(effect: effect, tick: viewModel.updateTick, onStop: {
                                        effect.stop()
                                    })
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadShow()
        }
    }
    
    /// Convert master volume slider value (0–1) to dB display string
    /// 0.5 = 0 dB (unity), 1.0 ≈ +6 dB, 0 = -∞ dB
    private func masterVolumeDB(_ value: Double) -> String {
        if value <= 0 { return "-∞ dB" }
        // Map slider so 0.5 = 0 dB (unity gain)
        // dB = 20 * log10(value / 0.5)
        let dB = 20.0 * log10(value / 0.5)
        if abs(dB) < 0.05 { return "0.00 dB" }
        return String(format: "%+.2f dB", dB)
    }
}

// MARK: - Active Effect Row

struct MacActiveEffectRow: View {
    let effect: FxEffect
    let tick: UInt  // Forces re-render when view model ticks
    let onStop: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(effect.name)
                        .font(.body)
                        .fontWeight(.medium)
                    Text(effect.status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Counter
                Text(formattedCounter)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(counterColor.opacity(0.2))
                    )
                    .foregroundColor(counterColor)
                
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            
            // Progress bar
            if effect.type == fx.TYPE_AUDIO {
                let duration = max(1, Double(effect.getDuration()))
                let position = min(max(0, Double(effect.getPosition())), duration)
                ProgressView(value: position, total: duration)
                    .tint(.blue)
            }
            
            // Volume slider
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: Binding(
                    get: {
                        if effect.stream >= 0 {
                            return Double(fx.audio.getLevel(effect.stream))
                        }
                        return Double(effect.currentVolume)
                    },
                    set: { newValue in
                        effect.currentVolume = Float(newValue)
                        fx.audio.setLevel(effect.stream, level: Float(newValue))
                        if !settings.performanceMode {
                            effect.level = Float(newValue)
                        }
                    }
                ), in: 0...2)
                .tint(effect.currentVolume > 1.0 ? .orange : .blue)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }
    
    private var formattedCounter: String {
        let raw = effect.getCounter()
        let clean = raw.hasPrefix("-") ? "00:00" : raw
        let parts = clean.split(separator: ":")
        guard parts.count >= 2 else { return "00:00" }
        let mins = Int(parts[0]) ?? 0
        let secsStr = String(parts[1]).split(separator: ".").first.map(String.init) ?? "0"
        let secs = Int(secsStr) ?? 0
        let total = max(0, mins * 60 + secs)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
    
    private var counterColor: Color {
        if effect.getRemaining() < Float(settings.countDownWarning) && !effect.loop {
            return .red
        }
        return .primary
    }
}

// MARK: - View Model

@MainActor
class MacPerformViewModel: ObservableObject {
    @Published var cues: [FxCue] = []
    @Published var activeEffects: [FxEffect] = []
    @Published var spotEffects: [FxEffect] = []
    @Published var currentCueName = ""
    @Published var currentCueNotes = ""
    @Published var nextCueName = ""
    @Published var activeCueIndex: Int?
    @Published var nextCueIndex: Int?
    @Published var masterVolume: Double = 0.5 {
        didSet { fx.audio.globalVolume(Float(masterVolume)) }
    }
    @Published var isPaused = false
    @Published var isAutoFollowActive = false
    @Published var autoFollowCountdown = ""
    @Published var updateTick: UInt = 0  // Forces UI refresh for live data
    
    private var timer: Timer?
    
    init() {
        // Apply default master volume on startup (0.5 = 0 dB)
        fx.audio.globalVolume(0.5)
        
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
        
        // Increment tick to force SwiftUI to re-render live data (progress, volume, counters)
        updateTick &+= 1
        
        if fx.show.currentVersion.activeCueNo >= 0 && fx.show.currentVersion.activeCueNo < cues.count {
            let currentCue = fx.show.currentVersion.getCue(fx.show.currentVersion.activeCueNo)
            currentCueName = currentCue.getName()
            let newIdx = fx.show.currentVersion.activeCueNo
            if activeCueIndex != newIdx { activeCueIndex = newIdx }
            spotEffects = currentCue.spotEffects
            
            checkAutoFollow(currentCue: currentCue)
        }
        
        if fx.show.currentVersion.nextCueNo >= 0 && fx.show.currentVersion.nextCueNo < cues.count {
            let nextCue = fx.show.currentVersion.getCue(fx.show.currentVersion.nextCueNo)
            nextCueName = nextCue.getName()
            currentCueNotes = nextCue.notes
            nextCueIndex = fx.show.currentVersion.nextCueNo
        }
        
        isPaused = fx.paused
    }
    
    private func checkAutoFollow(currentCue: FxCue) {
        if fx.autoFollowActive && !fx.emergencyStopActive {
            let elapsed = CACurrentMediaTime() - fx.autoFollowStart
            let remaining = Double(currentCue.autoFollowDelay) - elapsed
            
            if remaining > 0 {
                isAutoFollowActive = true
                autoFollowCountdown = formatDuration(Float(remaining))
            } else {
                autoFollowCountdown = "00:00"
                isAutoFollowActive = false
                fx.autoFollowActive = false
                currentCue.allowAutoFollow = false
                go()
            }
        } else if currentCue.allowAutoFollow && currentCue.autoFollow && currentCue.autoFollowEnd {
            if fx.activeEffects.count == 0 && !fx.emergencyStopActive {
                if !fx.autoFollowActive {
                    fx.autoFollowActive = true
                    fx.autoFollowStart = CACurrentMediaTime()
                }
                
                let elapsed = CACurrentMediaTime() - fx.autoFollowStart
                let remaining = Double(currentCue.autoFollowDelay) - elapsed
                
                if remaining > 0 {
                    isAutoFollowActive = true
                    autoFollowCountdown = formatDuration(Float(remaining))
                } else {
                    autoFollowCountdown = "00:00"
                    isAutoFollowActive = false
                    fx.autoFollowActive = false
                    currentCue.allowAutoFollow = false
                    go()
                }
            } else {
                if isAutoFollowActive { isAutoFollowActive = false }
            }
        } else {
            if isAutoFollowActive {
                isAutoFollowActive = false
                autoFollowCountdown = ""
            }
        }
    }
    
    func formatDuration(_ seconds: Float) -> String {
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
        let currentCue = fx.show.currentVersion.getCue(fx.show.currentVersion.activeCueNo)
        
        if fx.autoFollowActive || currentCue.allowAutoFollow {
            fx.autoFollowActive = false
            currentCue.allowAutoFollow = false
            isAutoFollowActive = false
            updateDisplay()
            return
        }
        
        fx.show.currentVersion.Go()
        
        let newCue = fx.show.currentVersion.getCue(fx.show.currentVersion.activeCueNo)
        if newCue.autoFollow && !newCue.autoFollowEnd {
            fx.autoFollowActive = true
            fx.autoFollowStart = CACurrentMediaTime()
            newCue.allowAutoFollow = true
            isAutoFollowActive = true
        }
        if newCue.autoFollow && newCue.autoFollowEnd {
            newCue.allowAutoFollow = true
            isAutoFollowActive = true
        }
        
        updateDisplay()
    }
    
    func playSpotEffect(at index: Int) {
        guard index < spotEffects.count else { return }
        let spot = spotEffects[index].clone()
        spot.spotPlay()
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
