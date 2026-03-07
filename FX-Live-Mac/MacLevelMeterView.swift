//
//  MacLevelMeterView.swift
//  FX-Live-Mac
//
//  Professional stereo audio level meter for macOS.
//  Supports single-bus (default mixer) and multi-bus (per-output) metering.
//  Based on the iPad's AudioLevelMeterView but adapted for Mac screen space.
//

import SwiftUI

// MARK: - Stereo Level Meter (Single Bus)

/// A single stereo level meter with L/R bars, dB scale, and peak hold.
/// Pass leftLevel and rightLevel in dB (−100…0).
struct MacStereoMeter: View {
    let leftLevel: Float
    let rightLevel: Float
    var label: String = ""
    var showScale: Bool = true
    
    private let dbMarks: [Float] = [0, -3, -6, -12, -24, -48]
    private let minDB: Float = -60
    private let maxDB: Float = 0
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if showScale {
                    dbScaleLabels(height: geometry.size.height)
                        .frame(width: 22)
                }
                
                // Left channel bar
                MacMeterBar(
                    level: leftLevel,
                    minDB: minDB,
                    maxDB: maxDB,
                    channelLabel: "L"
                )
                .frame(width: 8)
                
                Spacer().frame(width: 1)
                
                // Right channel bar
                MacMeterBar(
                    level: rightLevel,
                    minDB: minDB,
                    maxDB: maxDB,
                    channelLabel: "R"
                )
                .frame(width: 8)
                
                // Bus label
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(-90))
                        .fixedSize()
                        .frame(width: 10)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func dbScaleLabels(height: CGFloat) -> some View {
        ZStack(alignment: .trailing) {
            ForEach(dbMarks, id: \.self) { db in
                let fraction = (db - minDB) / (maxDB - minDB)
                let y = height * (1 - CGFloat(fraction))
                
                HStack(spacing: 1) {
                    Text(db == 0 ? " 0" : String(format: "%.0f", db))
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(colorForDB(db).opacity(0.9))
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 3, height: 1)
                }
                .position(x: 11, y: y)
            }
        }
    }
    
    private func colorForDB(_ db: Float) -> Color {
        if db > -3 { return .red }
        if db > -12 { return .yellow }
        return .green
    }
}

// MARK: - Individual Meter Bar

struct MacMeterBar: View {
    let level: Float
    let minDB: Float
    let maxDB: Float
    let channelLabel: String
    
    @State private var peakHold: Float = -100
    @State private var peakDecayCounter: Int = 0
    
    private var levelFraction: CGFloat {
        CGFloat(max(0, min(1, (level - minDB) / (maxDB - minDB))))
    }
    
    private var peakFraction: CGFloat {
        CGFloat(max(0, min(1, (peakHold - minDB) / (maxDB - minDB))))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let barHeight = geometry.size.height
            let barWidth = geometry.size.width
            let fillHeight = barHeight * levelFraction
            
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(white: 0.08))
                
                // Gradient fill
                if fillHeight > 0 {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        MacMeterGradient()
                            .frame(height: fillHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 1.5))
                            .animation(.linear(duration: 0.06), value: levelFraction)
                    }
                }
                
                // Peak hold line
                if peakFraction > 0.01 {
                    Rectangle()
                        .fill(peakColor)
                        .frame(width: barWidth, height: 2)
                        .offset(y: -(barHeight * peakFraction - 1))
                }
                
                // Segment lines
                ForEach(0..<segmentCount(barHeight), id: \.self) { i in
                    let segY = barHeight * CGFloat(i) / CGFloat(segmentCount(barHeight))
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: barWidth, height: 1)
                        .offset(y: -barHeight / 2 + segY)
                }
            }
        }
        .onChange(of: level) { _, newLevel in
            updatePeak(newLevel)
        }
    }
    
    private var peakColor: Color {
        if peakHold > -3 { return .red }
        if peakHold > -12 { return .yellow }
        return .green
    }
    
    private func segmentCount(_ height: CGFloat) -> Int {
        max(1, Int(height / 4))
    }
    
    private func updatePeak(_ newLevel: Float) {
        if newLevel > peakHold {
            peakHold = newLevel
            peakDecayCounter = 0
        } else {
            peakDecayCounter += 1
            if peakDecayCounter > 10 { // ~1 second at 10Hz refresh
                peakHold = max(newLevel, peakHold - 1.5)
            }
        }
    }
}

// MARK: - Meter Gradient Fill

struct MacMeterGradient: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color.green.opacity(0.9), location: 0.0),
                .init(color: Color.green, location: 0.5),
                .init(color: Color.yellow, location: 0.75),
                .init(color: Color.orange, location: 0.88),
                .init(color: Color.red, location: 0.95),
                .init(color: Color.red, location: 1.0)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

// MARK: - Multi-Output Meter Strip

/// Shows meters for all active output buses when multi-output is enabled,
/// or a single master meter when in default mode.
struct MacOutputMeterStrip: View {
    let meterLeftDB: Float
    let meterRightDB: Float
    let busLevels: [(left: Float, right: Float)]
    let multiOutputEnabled: Bool
    let busCount: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("OUTPUT")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.top, 6)
                .padding(.bottom, 2)
            
            if multiOutputEnabled && busCount > 0 {
                // Multi-output: label row at top
                HStack(spacing: 2) {
                    // Spacer for dB scale column
                    Spacer().frame(width: 22)
                    ForEach(Array(0..<busCount), id: \.self) { i in
                        Text(OutputBus.labelFor(i))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 18, alignment: .center)
                    }
                }
                .padding(.bottom, 2)
                
                // Multi-output: show one meter per bus
                HStack(spacing: 2) {
                    ForEach(Array(0..<busCount), id: \.self) { i in
                        MacStereoMeter(
                            leftLevel: busLeft(i),
                            rightLevel: busRight(i),
                            label: "",
                            showScale: i == 0
                        )
                        .frame(width: i == 0 ? 40 : 18)
                    }
                }
                .padding(.horizontal, 4)
            } else {
                // Single output: L/R labels at top
                HStack(spacing: 0) {
                    Spacer().frame(width: 22)
                    Text("L")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.green.opacity(0.8))
                        .frame(width: 8, alignment: .center)
                    Spacer().frame(width: 1)
                    Text("R")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.green.opacity(0.8))
                        .frame(width: 8, alignment: .center)
                }
                .padding(.bottom, 2)
                
                // Single output: master stereo meter
                MacStereoMeter(
                    leftLevel: meterLeftDB,
                    rightLevel: meterRightDB,
                    showScale: true
                )
                .frame(width: 42)
            }
            
            Spacer().frame(height: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
    }
    
    private func busLeft(_ i: Int) -> Float {
        guard i < busLevels.count else { return -100 }
        return busLevels[i].left
    }
    
    private func busRight(_ i: Int) -> Float {
        guard i < busLevels.count else { return -100 }
        return busLevels[i].right
    }
}

// MARK: - Compact Horizontal Meter (for design view)

/// A compact horizontal stereo meter for inline use in the design view.
struct MacCompactMeter: View {
    let leftLevel: Float
    let rightLevel: Float
    
    private let minDB: Float = -60
    private let maxDB: Float = 0
    
    var body: some View {
        VStack(spacing: 2) {
            // Left bar
            MacHorizontalBar(level: leftLevel, label: "L", minDB: minDB, maxDB: maxDB)
                .frame(height: 6)
            // Right bar
            MacHorizontalBar(level: rightLevel, label: "R", minDB: minDB, maxDB: maxDB)
                .frame(height: 6)
        }
    }
}

struct MacHorizontalBar: View {
    let level: Float
    let label: String
    let minDB: Float
    let maxDB: Float
    
    @State private var peakHold: Float = -100
    @State private var peakDecayCounter: Int = 0
    
    private var fraction: CGFloat {
        CGFloat(max(0, min(1, (level - minDB) / (maxDB - minDB))))
    }
    
    private var peakFraction: CGFloat {
        CGFloat(max(0, min(1, (peakHold - minDB) / (maxDB - minDB))))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let fillWidth = width * fraction
            
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(white: 0.08))
                
                // Fill
                if fillWidth > 0 {
                    HStack(spacing: 0) {
                        LinearGradient(
                            stops: [
                                .init(color: Color.green.opacity(0.9), location: 0.0),
                                .init(color: Color.green, location: 0.5),
                                .init(color: Color.yellow, location: 0.75),
                                .init(color: Color.orange, location: 0.88),
                                .init(color: Color.red, location: 0.95),
                                .init(color: Color.red, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: fillWidth)
                        .clipShape(RoundedRectangle(cornerRadius: 1.5))
                        .animation(.linear(duration: 0.06), value: fraction)
                        
                        Spacer(minLength: 0)
                    }
                }
                
                // Peak hold
                if peakFraction > 0.01 {
                    Rectangle()
                        .fill(peakHold > -3 ? Color.red : (peakHold > -12 ? Color.yellow : Color.green))
                        .frame(width: 2, height: height)
                        .offset(x: width * peakFraction - 1)
                }
            }
        }
        .onChange(of: level) { _, newLevel in
            if newLevel > peakHold {
                peakHold = newLevel
                peakDecayCounter = 0
            } else {
                peakDecayCounter += 1
                if peakDecayCounter > 10 {
                    peakHold = max(newLevel, peakHold - 1.5)
                }
            }
        }
    }
}
