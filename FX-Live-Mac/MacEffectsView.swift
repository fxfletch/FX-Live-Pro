//
//  MacEffectsView.swift
//  FX-Live-Mac
//
//  EQ, Reverb and Echo effects panel for the Design view.
//  Mirrors the iPad's EQSettingsSheet + DSPViewController in a persistent sidebar panel.
//

import SwiftUI

// MARK: - Effects Panel (4th column in Design view)

struct MacEffectsPanel: View {
    @ObservedObject var viewModel: MacDesignViewModel

    var body: some View {
        if let effect = viewModel.currentEffect,
           effect.type == fx.TYPE_AUDIO || effect.type == fx.TYPE_MUSIC {
            ScrollView {
                VStack(spacing: 0) {
                    // Panel header
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.blue)
                        Text("EFFECTS")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        
                        // Reset all button
                        Button(action: { viewModel.resetAllEffects() }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.orange)
                        .help("Reset all EQ and DSP effects")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))

                    Divider()

                    VStack(spacing: 16) {
                        // EQ Section
                        MacEQSection(viewModel: viewModel, effect: effect)

                        Divider().padding(.horizontal, 8)

                        // Reverb Section
                        MacReverbSection(viewModel: viewModel, effect: effect)

                        Divider().padding(.horizontal, 8)

                        // Echo Section
                        MacEchoSection(viewModel: viewModel, effect: effect)
                    }
                    .padding(.vertical, 12)
                }
            }
        } else {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("Effects")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
                Text("Select an audio effect\nto adjust EQ and DSP")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.4))
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - EQ Section

private struct MacEQSection: View {
    @ObservedObject var viewModel: MacDesignViewModel
    let effect: FxEffect

    // Band definitions: name, color, default freq, freq range
    private let bands: [(name: String, color: Color, defaultFreq: Float, range: ClosedRange<Float>)] = [
        ("Low",  .red,   80,    20...500),
        ("Mid",  .green, 440,   200...5000),
        ("High", .blue,  10000, 2000...20000)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.purple)
                    .font(.caption)
                Text("Equalizer")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if effect.eqActive() {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 12)

            ForEach(0..<3, id: \.self) { i in
                MacEQBandRow(
                    viewModel: viewModel,
                    effect: effect,
                    bandIndex: i,
                    bandName: bands[i].name,
                    bandColor: bands[i].color,
                    defaultFreq: bands[i].defaultFreq,
                    freqRange: bands[i].range
                )
            }
        }
    }
}

// MARK: - EQ Band Row

private struct MacEQBandRow: View {
    @ObservedObject var viewModel: MacDesignViewModel
    let effect: FxEffect
    let bandIndex: Int
    let bandName: String
    let bandColor: Color
    let defaultFreq: Float
    let freqRange: ClosedRange<Float>

    private var eq: FxEq {
        guard bandIndex < effect.eq.count else { return FxEq() }
        return effect.eq[bandIndex]
    }

    var body: some View {
        VStack(spacing: 4) {
            // Band header with toggle
            HStack {
                Toggle(isOn: Binding(
                    get: { eq.active },
                    set: { newVal in
                        ensureBands()
                        effect.eq[bandIndex].active = newVal
                        applyEQ()
                    }
                )) {
                    Text(bandName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(eq.active ? bandColor : .secondary)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
            .padding(.horizontal, 12)

            if eq.active {
                // Frequency
                MacEffectSlider(
                    label: "Freq",
                    value: Binding(
                        get: { eq.frequency },
                        set: { newVal in
                            effect.eq[bandIndex].frequency = newVal
                            applyEQ()
                        }
                    ),
                    range: freqRange,
                    format: "%0.0f Hz",
                    color: bandColor
                )

                // Gain
                MacEffectSlider(
                    label: "Gain",
                    value: Binding(
                        get: { eq.gain },
                        set: { newVal in
                            effect.eq[bandIndex].gain = newVal
                            applyEQ()
                        }
                    ),
                    range: -15...15,
                    format: "%+.1f dB",
                    color: bandColor
                )

                // Bandwidth / Q
                MacEffectSlider(
                    label: "Q",
                    value: Binding(
                        get: { eq.bandwidth },
                        set: { newVal in
                            effect.eq[bandIndex].bandwidth = newVal
                            applyEQ()
                        }
                    ),
                    range: 0.1...10,
                    format: "%.1f",
                    color: bandColor
                )
            }
        }
        .padding(.vertical, 2)
    }

    private func ensureBands() {
        let defaultFreqs: [Float] = [80, 440, 10000]
        while effect.eq.count < 3 {
            let band = FxEq()
            band.frequency = defaultFreqs[effect.eq.count]
            effect.eq.append(band)
        }
    }

    private func applyEQ() {
        ensureBands()
        // Live update if the effect is currently playing
        if effect.isPlaying() {
            fx.updateEq(effect.eq)
        }
        // Also update preview stream if active
        if fx.previewStream != 0 && fx.previewStream != -1 {
            fx.updateEq(effect.eq)
        }
        fx.show.save()
        viewModel.objectWillChange.send()
    }
}

// MARK: - Reverb Section

private struct MacReverbSection: View {
    @ObservedObject var viewModel: MacDesignViewModel
    let effect: FxEffect

    private var dsp: FxDsp { effect.dsp }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Image(systemName: "waveform.path")
                    .foregroundColor(.cyan)
                    .font(.caption)
                Text("Reverb")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if dsp.reverbActive {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                }

                Toggle(isOn: Binding(
                    get: { dsp.reverbActive },
                    set: { newVal in
                        dsp.reverbActive = newVal
                        applyDSP()
                    }
                )) {
                    EmptyView()
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
            .padding(.horizontal, 12)

            if dsp.reverbActive {
                // Gain: -96 to 0 dB
                MacEffectSlider(
                    label: "Gain",
                    value: Binding(
                        get: { dsp.reverbGain },
                        set: { newVal in
                            dsp.reverbGain = newVal
                            applyDSP()
                        }
                    ),
                    range: -96...0,
                    format: "%.0f dB",
                    color: .cyan
                )

                // Mix: -96 to 0 dB
                MacEffectSlider(
                    label: "Mix",
                    value: Binding(
                        get: { dsp.reverbMix },
                        set: { newVal in
                            dsp.reverbMix = newVal
                            applyDSP()
                        }
                    ),
                    range: -96...0,
                    format: "%.0f dB",
                    color: .cyan
                )

                // Reverb Time: 0.001 to 3000 ms
                MacEffectSlider(
                    label: "Time",
                    value: Binding(
                        get: { dsp.reverbDelay },
                        set: { newVal in
                            dsp.reverbDelay = newVal
                            applyDSP()
                        }
                    ),
                    range: 0.001...3000,
                    format: "%.0f ms",
                    color: .cyan
                )
            }
        }
    }

    private func applyDSP() {
        if effect.isPlaying() {
            fx.updateDsp(effect.stream, dsp: dsp)
            for s in effect.additionalStreams {
                fx.updateDsp(s, dsp: dsp)
            }
        }
        if fx.previewStream != 0 && fx.previewStream != -1 {
            fx.updateDsp(fx.previewStream, dsp: dsp)
        }
        fx.show.save()
        viewModel.objectWillChange.send()
    }
}

// MARK: - Echo Section

private struct MacEchoSection: View {
    @ObservedObject var viewModel: MacDesignViewModel
    let effect: FxEffect

    private var dsp: FxDsp { effect.dsp }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Image(systemName: "repeat")
                    .foregroundColor(.orange)
                    .font(.caption)
                Text("Echo")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if dsp.echoActive {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                }

                Toggle(isOn: Binding(
                    get: { dsp.echoActive },
                    set: { newVal in
                        dsp.echoActive = newVal
                        applyDSP()
                    }
                )) {
                    EmptyView()
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
            .padding(.horizontal, 12)

            if dsp.echoActive {
                // Wet/Dry Mix: 0 to 100
                MacEffectSlider(
                    label: "Wet/Dry",
                    value: Binding(
                        get: { dsp.echoWetDry },
                        set: { newVal in
                            dsp.echoWetDry = newVal
                            applyDSP()
                        }
                    ),
                    range: 0...100,
                    format: "%.0f%%",
                    color: .orange
                )

                // Feedback: 0 to 100
                MacEffectSlider(
                    label: "Feedback",
                    value: Binding(
                        get: { dsp.echoFeedback },
                        set: { newVal in
                            dsp.echoFeedback = newVal
                            applyDSP()
                        }
                    ),
                    range: 0...100,
                    format: "%.0f%%",
                    color: .orange
                )

                // Left Delay: 1 to 2000 ms
                MacEffectSlider(
                    label: "Delay L",
                    value: Binding(
                        get: { dsp.echoDelayL },
                        set: { newVal in
                            dsp.echoDelayL = newVal
                            applyDSP()
                        }
                    ),
                    range: 1...2000,
                    format: "%.0f ms",
                    color: .orange
                )

                // Right Delay: 1 to 2000 ms
                MacEffectSlider(
                    label: "Delay R",
                    value: Binding(
                        get: { dsp.echoDelayR },
                        set: { newVal in
                            dsp.echoDelayR = newVal
                            applyDSP()
                        }
                    ),
                    range: 1...2000,
                    format: "%.0f ms",
                    color: .orange
                )
            }
        }
    }

    private func applyDSP() {
        if effect.isPlaying() {
            fx.updateDsp(effect.stream, dsp: dsp)
            for s in effect.additionalStreams {
                fx.updateDsp(s, dsp: dsp)
            }
        }
        if fx.previewStream != 0 && fx.previewStream != -1 {
            fx.updateDsp(fx.previewStream, dsp: dsp)
        }
        fx.show.save()
        viewModel.objectWillChange.send()
    }
}

// MARK: - Reusable Effect Slider

private struct MacEffectSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let format: String
    var color: Color = .blue

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 48, alignment: .trailing)

            Slider(value: $value, in: range)
                .controlSize(.small)
                .tint(color)

            Text(String(format: format, value))
                .font(.caption2)
                .monospacedDigit()
                .foregroundColor(.secondary)
                .frame(width: 56, alignment: .leading)
        }
        .padding(.horizontal, 12)
    }
}
