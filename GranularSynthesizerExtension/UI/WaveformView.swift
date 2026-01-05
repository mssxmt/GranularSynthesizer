//
//  WaveformView.swift
//  GranularSynthesizerExtension
//
//  Waveform display with region-based grain management
//

import SwiftUI

// MARK: - Playback Direction Enum

enum PlaybackDirection: Int, CaseIterable {
    case forward = 0
    case backward = 1
    case pingpong = 2
    case random = 3

    var displayName: String {
        switch self {
        case .forward: return "FW"
        case .backward: return "BF"
        case .pingpong: return "Both"
        case .random: return "Rnd"
        }
    }
}

// MARK: - Grain Region Model

struct GrainRegionModel: Identifiable {
    let id = UUID()
    var index: Int
    var startPosition: Float
    var endPosition: Float
    var gain: Float
    var active: Bool
    var jitter: Float
    var playbackDirection: Int
    var currentPosition: Float
    var playbackSpeed: Float

    // Per-region LFO parameters (for position/width modulation)
    var lfoEnabled: Bool = false
    var lfoWaveform: Int = 0          // 0=sine, 1=triangle, 2=square, 3=sawtooth, 4=S&H
    var lfoFrequency: Float = 1.0     // 0.1 - 20.0
    var lfoDepth: Float = 0.5         // 0.0 - 1.0
    var lfoTarget: Int = 0            // 0=off, 1=position, 2=width

    // Current LFO modulation values (for UI animation)
    var lfoPositionMod: Float = 0.0   // Current position modulation
    var lfoWidthMod: Float = 0.0      // Current width modulation

    var color: Color {
        let hue = Double(index) * 0.15
        return Color(hue: hue, saturation: 0.7, brightness: 0.85)
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    var audioUnit: AUAudioUnit?

    private static let downsampleFactor = 1000  // Higher value = more detailed waveform

    @State private var waveformData: [Float] = []
    @State private var grainRegions: [GrainRegionModel] = []
    @State private var selectedRegionIndex: Int? = nil
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            // Waveform display (visual only)
            GeometryReader { geometry in
                ZStack {
                    // Background with gradient
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.8), Color.black.opacity(0.4)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )

                    // Grid lines
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height

                        // Vertical lines
                        for i in 1...4 {
                            let x = width * CGFloat(i) / 5.0
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: height))
                        }

                        // Horizontal lines
                        for i in 1...3 {
                            let y = height * CGFloat(i) / 4.0
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                    }
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)

                    // Waveform with mirrored display
                    if !waveformData.isEmpty {
                        // Main waveform (top half)
                        Path { path in
                            let width = geometry.size.width
                            let height = geometry.size.height
                            let centerY = height / 2

                            for (index, sample) in waveformData.enumerated() {
                                let x = CGFloat(index) / CGFloat(waveformData.count) * width
                                let amplitude = abs(CGFloat(sample)) * height * 0.4

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: centerY - amplitude))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: centerY - amplitude))
                                }
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.9), Color.blue.opacity(0.7), Color.purple.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                        .shadow(color: Color.cyan.opacity(0.5), radius: 3, x: 0, y: 0)

                        // Mirrored waveform (bottom half)
                        Path { path in
                            let width = geometry.size.width
                            let height = geometry.size.height
                            let centerY = height / 2

                            for (index, sample) in waveformData.enumerated() {
                                let x = CGFloat(index) / CGFloat(waveformData.count) * width
                                let amplitude = abs(CGFloat(sample)) * height * 0.4

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: centerY + amplitude))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: centerY + amplitude))
                                }
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.5), Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                        .opacity(0.6)
                    }

                    // Grain regions (visual overlay)
                    ForEach(Array(grainRegions.enumerated()), id: \.element.id) { index, region in
                        if region.active {
                            let startX = CGFloat(region.startPosition) * geometry.size.width
                            let endX = CGFloat(region.endPosition) * geometry.size.width
                            let isSelected = selectedRegionIndex == index

                            // Region rectangle with gradient
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            region.color.opacity(isSelected ? 0.4 : 0.25),
                                            region.color.opacity(isSelected ? 0.25 : 0.15)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: max(20, endX - startX), height: geometry.size.height)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            LinearGradient(
                                                colors: [region.color, region.color.opacity(0.5)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: isSelected ? 2.5 : 1.5
                                        )
                                )
                                .shadow(color: region.color.opacity(0.3), radius: isSelected ? 8 : 4, x: 0, y: 0)
                                .position(x: (startX + endX) / 2, y: geometry.size.height / 2)
                                .allowsHitTesting(false)

                            // Region boundary indicators
                            Circle()
                                .fill(region.color)
                                .frame(width: isSelected ? 8 : 6, height: isSelected ? 8 : 6)
                                .shadow(color: region.color, radius: 4)
                                .position(x: startX, y: geometry.size.height / 2)
                                .allowsHitTesting(false)

                            Circle()
                                .fill(region.color)
                                .frame(width: isSelected ? 8 : 6, height: isSelected ? 8 : 6)
                                .shadow(color: region.color, radius: 4)
                                .position(x: endX, y: geometry.size.height / 2)
                                .allowsHitTesting(false)

                            // LFO modulation visualization (show actual modulated region)
                            if region.lfoEnabled && region.lfoTarget > 0 {
                                // LFO modulates position or width, show the actual range
                                let lfoModX = CGFloat(region.lfoPositionMod) * geometry.size.width
                                let lfoModWidth = CGFloat(region.lfoWidthMod) * geometry.size.width

                                // Calculate modulated region bounds
                                let modStartX = startX + lfoModX
                                let modEndX = endX + lfoModX

                                // For width modulation, expand both edges
                                if region.lfoTarget == 2 {
                                    let halfWidthMod = lfoModWidth / 2.0
                                    let visualStartX = modStartX - halfWidthMod
                                    let visualEndX = modEndX + halfWidthMod

                                    // Visualize the LFO modulated range as a dashed outline
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            Color.white.opacity(0.6),
                                            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                                        )
                                        .frame(width: max(20, visualEndX - visualStartX), height: geometry.size.height)
                                        .position(x: (visualStartX + visualEndX) / 2, y: geometry.size.height / 2)
                                        .allowsHitTesting(false)
                                } else {
                                    // Position modulation - show shifted region
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            Color.white.opacity(0.6),
                                            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                                        )
                                        .frame(width: max(20, modEndX - modStartX), height: geometry.size.height)
                                        .position(x: (modStartX + modEndX) / 2, y: geometry.size.height / 2)
                                        .allowsHitTesting(false)
                                }

                                // Show LFO target indicator
                                VStack(spacing: 2) {
                                    Image(systemName: "waveform.path")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                    Text(region.lfoTarget == 1 ? "POS" : "WID")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(6)
                                .position(x: (startX + endX) / 2, y: 20)
                                .allowsHitTesting(false)
                            }

                            // Playback position indicator (animated bar with glow)
                            let playbackX = CGFloat(region.currentPosition) * geometry.size.width
                            if playbackX >= startX && playbackX <= endX {
                                // Glow effect
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0),
                                                Color.white.opacity(0.8),
                                                Color.white.opacity(0)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 8, height: geometry.size.height)
                                    .blur(radius: 4)
                                    .position(x: playbackX, y: geometry.size.height / 2)
                                    .allowsHitTesting(false)

                                // Main indicator line
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white, Color.cyan],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 2.5, height: geometry.size.height)
                                    .shadow(color: Color.white.opacity(0.8), radius: 6, x: 0, y: 0)
                                    .position(x: playbackX, y: geometry.size.height / 2)
                                    .allowsHitTesting(false)

                                // Playhead dot
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 6, height: 6)
                                    .shadow(color: Color.white, radius: 4)
                                    .position(x: playbackX, y: geometry.size.height / 2)
                                    .allowsHitTesting(false)
                            }
                        }
                    }

                    // Center line
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: geometry.size.width, height: 1)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .allowsHitTesting(false)
                }
                .onAppear {
                    loadWaveform()
                }
            }
            .frame(height: 80)

            // Region selector buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(grainRegions.enumerated()), id: \.element.id) { index, region in
                        Button(action: {
                            selectedRegionIndex = index
                        }) {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(region.color.opacity(region.active ? 0.8 : 0.3))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedRegionIndex == index ? Color.white : region.color, lineWidth: 2)
                                    )
                                Text("R\(region.index + 1)")
                                    .font(.caption2)
                                    .foregroundColor(region.active ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 40)

            // Selected region controls with position sliders
            if let selectedIndex = selectedRegionIndex, selectedIndex < grainRegions.count {
                GrainRegionControls(
                    region: Binding(
                        get: { grainRegions[selectedIndex] },
                        set: { newValue in
                            if selectedIndex < grainRegions.count {
                                grainRegions[selectedIndex] = newValue
                            }
                        }
                    ),
                    audioUnit: audioUnit,
                    onUpdate: {
                        loadGrainRegions()
                    }
                )
                .transition(.opacity)
            }

            // Add/Remove buttons
            HStack(spacing: 16) {
                Button(action: addGrainRegion) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Region")
                    }
                    .font(.caption)
                }
                .disabled(grainRegions.count >= 8)

                Button(action: removeSelectedRegion) {
                    HStack {
                        Image(systemName: "minus.circle.fill")
                        Text("Remove Region")
                    }
                    .font(.caption)
                }
                .disabled(grainRegions.count <= 1 || selectedRegionIndex == nil)
            }
        }
        .overlay(
            // Hide AUv3 component info ("aumu GrnS Mxmt") displayed by host
            VStack {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 24)
                Spacer()
            }
            .allowsHitTesting(false)
        )
        .onAppear {
            loadGrainRegions()
            if selectedRegionIndex == nil && !grainRegions.isEmpty {
                selectedRegionIndex = 0
            }
            startPlaybackAnimation()
        }
        .onDisappear {
            stopPlaybackAnimation()
        }
    }

    private func startPlaybackAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            updatePlaybackPositions()
        }
    }

    private func stopPlaybackAnimation() {
        timer?.invalidate()
        timer = nil
    }

    private func updatePlaybackPositions() {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }

        let count = Int(audioUnit.getGrainRegionCount())
        for i in 0..<min(count, grainRegions.count) {
            let pos = audioUnit.getRegionPlaybackPosition(CInt(i))
            grainRegions[i].currentPosition = Float(pos)

            // Update LFO modulation values for animation
            grainRegions[i].lfoPositionMod = audioUnit.getRegionLFOPositionMod(CInt(i))
            grainRegions[i].lfoWidthMod = audioUnit.getRegionLFOWidthMod(CInt(i))

            // Get DSP calculated actual position (with LFO applied)
            if let regionData = audioUnit.getGrainRegion(CInt(i)) {
                // Use DSP calculated position for visualization
                grainRegions[i].startPosition = regionData.startPosition
                grainRegions[i].endPosition = regionData.endPosition
            }
        }
    }

    private func loadWaveform() {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }

        let size = audioUnit.getWaveformSize()
        guard let fullData = audioUnit.getWaveformData() else {
            return
        }

        var downsampled: [Float] = []
        let intSize = Int(size)
        let step = max(1, intSize / Self.downsampleFactor)

        for i in stride(from: 0, to: intSize, by: step) {
            if i < fullData.count {
                downsampled.append(Float(fullData[i].floatValue))
            }
        }

        waveformData = downsampled
    }

    private func loadGrainRegions() {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }

        let count = audioUnit.getGrainRegionCount()
        var regions: [GrainRegionModel] = []

        for i in 0..<count {
            if let regionData = audioUnit.getGrainRegion(Int32(i)) {
                var model = GrainRegionModel(
                    index: Int(i),
                    startPosition: regionData.startPosition,  // DSP calculated actual position
                    endPosition: regionData.endPosition,      // DSP calculated actual end position
                    gain: regionData.gain,
                    active: regionData.active,
                    jitter: regionData.jitter,
                    playbackDirection: regionData.playbackDirection,
                    currentPosition: regionData.currentPosition,
                    playbackSpeed: regionData.playbackSpeed
                )
                // LFO parameters
                model.lfoEnabled = regionData.lfoEnabled
                model.lfoWaveform = regionData.lfoWaveform
                model.lfoFrequency = regionData.lfoFrequency
                model.lfoDepth = regionData.lfoDepth
                model.lfoTarget = regionData.lfoTarget
                // Manual values (for XY Pad - center based)
                // startPosition is now center-based, so we use it directly
                model.startPosition = regionData.manualPosition  // Center position for XY pad
                model.endPosition = regionData.manualPosition + regionData.manualWidth  // Using manualWidth for display
                regions.append(model)
            }
        }

        grainRegions = regions
    }

    private func addGrainRegion() {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }

        audioUnit.addGrainRegion()
        loadGrainRegions()
        selectedRegionIndex = grainRegions.count - 1
    }

    private func removeSelectedRegion() {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit,
              let index = selectedRegionIndex else {
            return
        }

        audioUnit.removeGrainRegion(Int32(index))
        selectedRegionIndex = max(0, index - 1)
        loadGrainRegions()
    }
}

// MARK: - Region Parameter Slider Component

struct RegionParameterSlider: View {
    var name: String
    @Binding var value: Float
    var range: ClosedRange<Float>
    var format: String = "%.2f"
    var color: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: format, value))
                    .font(.caption2)
                    .foregroundColor(color)
            }
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Float($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound)
            )
            .accentColor(color)
        }
    }
}

// MARK: - XY Pad Component

struct XYPadView: View {
    @Binding var position: Float      // X軸: 0.0 to 1.0
    @Binding var width: Float         // Y軸: 0.02 to 1.0
    @Binding var lfoEnabled: Bool
    var lfoTarget: Int                // 現在のLFOターゲット
    var regionColor: Color
    var lfoPositionMod: Float         // 現在のLFO position modulation
    var lfoWidthMod: Float            // 現在のLFO width modulation
    var onChanged: (Float, Float) -> Void

    @State private var isDragging = false

    // Calculate actual position with LFO modulation (DSP logic)
    private var actualLFOValues: (position: Float, width: Float) {
        guard lfoEnabled && lfoTarget > 0 else {
            return (position, width)
        }

        let actualWidth = width * (1.0 + lfoWidthMod)
        let clampedWidth = max(0.02, min(1.0, actualWidth))
        let actualPos = position + lfoPositionMod

        let leftEdge = actualPos - clampedWidth / 2.0
        let rightEdge = actualPos + clampedWidth / 2.0

        var finalPos = actualPos
        if leftEdge < 0.0 || rightEdge > 1.0 {
            let space = 1.0 - clampedWidth
            if space >= 0.0 {
                finalPos = clampedWidth / 2.0 + space / 2.0
            } else {
                finalPos = 0.5
            }
        }

        finalPos = max(clampedWidth / 2.0, min(1.0 - clampedWidth / 2.0, finalPos))
        return (finalPos, clampedWidth)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with grid
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.6), Color.black.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(regionColor.opacity(0.3), lineWidth: 1)
                    )

                // Grid lines
                Path { path in
                    let w = geometry.size.width
                    let h = geometry.size.height

                    // Vertical lines
                    for i in 1...4 {
                        let x = w * CGFloat(i) / 5.0
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: h))
                    }

                    // Horizontal lines
                    for i in 1...4 {
                        let y = h * CGFloat(i) / 5.0
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)

                // LFO visualization (when enabled)
                if lfoEnabled && lfoTarget > 0 {
                    let (finalPos, clampedWidth) = actualLFOValues

                    // Manual position (what user set via XY pad)
                    let manualX = CGFloat(position) * geometry.size.width
                    let manualY = (1.0 - CGFloat(width)) * geometry.size.height

                    // Actual position (with DSP applied LFO modulation)
                    let actualX = CGFloat(finalPos) * geometry.size.width
                    let actualY = (1.0 - CGFloat(clampedWidth)) * geometry.size.height

                    // Manual position indicator (faded, what user set)
                    Circle()
                        .fill(regionColor.opacity(0.3))
                        .frame(width: 10, height: 10)
                        .position(x: manualX, y: manualY)

                    // Modulation line (from manual to actual)
                    Path { path in
                        path.move(to: CGPoint(x: manualX, y: manualY))
                        path.addLine(to: CGPoint(x: actualX, y: actualY))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundColor(regionColor.opacity(0.5))

                    // Actual position dot (bright, DSP calculated)
                    Circle()
                        .fill(regionColor)
                        .frame(width: 12, height: 12)
                        .shadow(color: regionColor, radius: 6)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .position(x: actualX, y: actualY)
                        .animation(.linear(duration: 0.05), value: lfoPositionMod)
                        .animation(.linear(duration: 0.05), value: lfoWidthMod)
                } else {
                    // Current position dot (no LFO)
                    Circle()
                        .fill(regionColor)
                        .frame(width: isDragging ? 14 : 12, height: isDragging ? 14 : 12)
                        .shadow(color: regionColor, radius: isDragging ? 8 : 4)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .position(
                            x: CGFloat(position) * geometry.size.width,
                            y: (1.0 - CGFloat(width)) * geometry.size.height
                        )
                }

                // Drag gesture
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                var newPosition = Float(value.location.x / geometry.size.width)
                                var newWidth = Float(1.0 - value.location.y / geometry.size.height)

                                // Clamp values (DSP handles symmetric boundaries)
                                newPosition = max(0.0, min(1.0, newPosition))
                                newWidth = max(0.02, min(1.0, newWidth))

                                position = newPosition
                                width = newWidth
                                onChanged(newPosition, newWidth)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
        }
        .frame(height: 150)
        .overlay(
            VStack {
                HStack {
                    // LFO indicator
                    if lfoEnabled {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform.path")
                                .font(.caption2)
                            Text(lfoTarget == 1 ? "POS" : (lfoTarget == 2 ? "WID" : "-"))
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(regionColor.opacity(0.3))
                        .cornerRadius(4)
                    }

                    Spacer()

                    // Position value (show actual when LFO enabled)
                    if lfoEnabled && lfoTarget > 0 {
                        let (finalPos, clampedWidth) = actualLFOValues

                        HStack(spacing: 4) {
                            Text("X: \(String(format: "%.2f", position))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("→\(String(format: "%.2f", finalPos))")
                                .font(.caption2)
                                .foregroundColor(regionColor)
                        }

                        HStack(spacing: 4) {
                            Text("Y: \(String(format: "%.2f", width))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("→\(String(format: "%.2f", clampedWidth))")
                                .font(.caption2)
                                .foregroundColor(regionColor)
                        }
                    } else {
                        // Manual values only (no LFO)
                        Text("X: \(String(format: "%.2f", position))")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("Y: \(String(format: "%.2f", width))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        )
    }
}

// MARK: - Region Position/Width Sliders

struct RegionSliderView: View {
    @Binding var position: Float       // Left edge position: 0.0 to 1.0
    @Binding var width: Float          // Width from left edge: 0.02 to 1.0
    @Binding var lfoEnabled: Bool
    var lfoTarget: Int
    var regionColor: Color
    var lfoPositionMod: Float
    var lfoWidthMod: Float
    var onChanged: (Float, Float) -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Start Point Slider (Left Edge)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Start Point")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f", position))
                        .font(.caption2)
                        .foregroundColor(regionColor)
                }
                Slider(
                    value: Binding(
                        get: { Double(position) },
                        set: { newValue in
                            // Constrain: left edge must leave room for current width
                            let maxValue = 1.0 - Double(width)
                            position = Float(max(0.0, min(maxValue, newValue)))
                            onChanged(position, width)
                        }
                    ),
                    in: 0...1
                )
                .accentColor(regionColor)
            }

            // End Point Slider (width from left edge)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("End Point")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f", width))
                        .font(.caption2)
                        .foregroundColor(regionColor)
                }
                Slider(
                    value: Binding(
                        get: { Double(width) },
                        set: { newValue in
                            // Constrain: width must fit from current position
                            let maxValue = 1.0 - Double(position)
                            width = Float(max(0.02, min(maxValue, newValue)))
                            onChanged(position, width)
                        }
                    ),
                    in: 0.02...1
                )
                .accentColor(regionColor)
            }

            // LFO indicator
            if lfoEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path")
                        .font(.caption2)
                    Text(lfoTarget == 1 ? "POS" : (lfoTarget == 2 ? "WID" : "-"))
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(regionColor.opacity(0.3))
                .cornerRadius(4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Region LFO Section

struct RegionLFOSection: View {
    @Binding var region: GrainRegionModel
    var audioUnit: AUAudioUnit?
    var regionColor: Color

    private let waveforms: [(name: String, tag: Int)] = [
        ("Sine", 0),
        ("Tri", 1),
        ("Sqr", 2),
        ("Saw", 3),
        ("S&H", 4)
    ]

    private let targets: [(name: String, tag: Int)] = [
        ("Off", 0),
        ("Pos", 1),
        ("Wid", 2)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with LFO enable toggle
            HStack(spacing: 6) {
                Image(systemName: "waveform.path")
                    .foregroundColor(regionColor)
                Text("LFO")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(regionColor)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { region.lfoEnabled },
                    set: { newValue in
                        region.lfoEnabled = newValue
                        updateLFOEnabled(newValue)
                    }
                ))
                .toggleStyle(SwitchToggleStyle())
                .labelsHidden()
            }

            Divider()

            // Waveform and Target pickers
            HStack(spacing: 12) {
                // Waveform
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wave")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Picker("", selection: Binding(
                        get: { region.lfoWaveform },
                        set: { newValue in
                            region.lfoWaveform = newValue
                            updateLFOWaveform(newValue)
                        }
                    )) {
                        ForEach(waveforms, id: \.tag) { waveform in
                            Text(waveform.name).tag(waveform.tag)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                // Target
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Picker("", selection: Binding(
                        get: { region.lfoTarget },
                        set: { newValue in
                            region.lfoTarget = newValue
                            updateLFOTarget(newValue)
                        }
                    )) {
                        ForEach(targets, id: \.tag) { target in
                            Text(target.name).tag(target.tag)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }

            // Frequency and Depth sliders
            VStack(spacing: 8) {
                RegionParameterSlider(
                    name: "Freq",
                    value: Binding(
                        get: { region.lfoFrequency },
                        set: { newValue in
                            region.lfoFrequency = newValue
                            updateLFOFrequency(newValue)
                        }
                    ),
                    range: 0.1...20.0,
                    format: "%.1fHz",
                    color: regionColor
                )

                RegionParameterSlider(
                    name: "Depth",
                    value: Binding(
                        get: { region.lfoDepth },
                        set: { newValue in
                            region.lfoDepth = newValue
                            updateLFODepth(newValue)
                        }
                    ),
                    range: 0.0...1.0,
                    format: "%.2f",
                    color: regionColor
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(regionColor.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(regionColor.opacity(0.4), lineWidth: 1)
        )
    }

    private func updateLFOEnabled(_ value: Bool) {
        (audioUnit as? GranularSynthesizerExtensionAudioUnit)?.setRegionLFOEnabled(Int32(region.index), enabled: value)
    }

    private func updateLFOWaveform(_ value: Int) {
        (audioUnit as? GranularSynthesizerExtensionAudioUnit)?.setRegionLFOWaveform(Int32(region.index), waveform: value)
    }

    private func updateLFOFrequency(_ value: Float) {
        (audioUnit as? GranularSynthesizerExtensionAudioUnit)?.setRegionLFOFrequency(Int32(region.index), frequency: value)
    }

    private func updateLFODepth(_ value: Float) {
        (audioUnit as? GranularSynthesizerExtensionAudioUnit)?.setRegionLFODepth(Int32(region.index), depth: value)
    }

    private func updateLFOTarget(_ value: Int) {
        (audioUnit as? GranularSynthesizerExtensionAudioUnit)?.setRegionLFOTarget(Int32(region.index), target: value)
    }
}

// MARK: - Grain Region Controls (New Layout)

struct GrainRegionControls: View {
    @Binding var region: GrainRegionModel
    var audioUnit: AUAudioUnit?
    var onUpdate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Header with enable toggle
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(region.color)
                        .frame(width: 8, height: 8)
                    Text("Region \(region.index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(region.color)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { region.active },
                    set: { newValue in
                        updateActiveState(newValue)
                    }
                ))
                .labelsHidden()
            }

            // Main parameters (left) and LFO (right) side by side
            HStack(alignment: .top, spacing: 12) {
                // Left side: Start/End sliders + Main parameters
                VStack(spacing: 10) {
                    // Region Slider for Start/End Point
                    RegionSliderView(
                        position: Binding(
                            get: { region.startPosition },  // Left edge position
                            set: { newLeftEdge in
                                let currentWidth = region.endPosition - region.startPosition
                                let newRightEdge = newLeftEdge + currentWidth
                                updateRegionPositions(start: newLeftEdge, end: newRightEdge)
                            }
                        ),
                        width: Binding(
                            get: { max(0.02, region.endPosition - region.startPosition) },
                            set: { newWidth in
                                let leftEdge = region.startPosition
                                let newRightEdge = leftEdge + newWidth
                                updateRegionPositions(start: leftEdge, end: newRightEdge)
                            }
                        ),
                        lfoEnabled: $region.lfoEnabled,
                        lfoTarget: region.lfoTarget,
                        regionColor: region.color,
                        lfoPositionMod: region.lfoPositionMod,
                        lfoWidthMod: region.lfoWidthMod,
                        onChanged: { newLeftEdge, newWidth in
                            // Send to DSP directly: left edge + width (no center calculation)
                            updateRegionPositionsFromUI(leftEdge: newLeftEdge, width: newWidth)
                        }
                    )

                    HStack(spacing: 12) {
                        RegionParameterSlider(
                            name: "Gain",
                            value: Binding(
                                get: { region.gain },
                                set: { updateGain($0) }
                            ),
                            range: 0...1,
                            format: "%.2f",
                            color: region.color
                        )

                        RegionParameterSlider(
                            name: "Speed",
                            value: Binding(
                                get: { region.playbackSpeed * 441000 },
                                set: { updatePlaybackSpeed($0 / 441000.0) }
                            ),
                            range: 1...100,
                            format: "%.0f",
                            color: region.color
                        )

                        RegionParameterSlider(
                            name: "Jitter",
                            value: Binding(
                                get: { region.jitter },
                                set: { updateJitter($0) }
                            ),
                            range: 0...1,
                            format: "%.2f",
                            color: region.color
                        )
                    }
                    .padding(.horizontal, 8)

                    // Playback direction
                    HStack {
                        Text("Direction")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Picker("", selection: Binding(
                            get: { region.playbackDirection },
                            set: { updatePlaybackDirection($0) }
                        )) {
                            ForEach(Array(PlaybackDirection.allCases.enumerated()), id: \.offset) { _, direction in
                                Text(direction.displayName).tag(direction.rawValue)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal, 8)
                }

                // Right side: LFO Section
                RegionLFOSection(
                    region: $region,
                    audioUnit: audioUnit,
                    regionColor: region.color
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(region.color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(region.color.opacity(0.3), lineWidth: 1)
        )
    }

    private func updateRegionPositionsFromUI(leftEdge: Float, width: Float) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else { return }
        // DSP now expects left edge and width directly
        audioUnit.setRegionManualPosition(Int32(region.index), position: leftEdge)
        audioUnit.setRegionManualWidth(Int32(region.index), width: width)
        onUpdate()
    }

    private func updateRegionPositions(start: Float, end: Float) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else { return }
        // Ensure minimum width and valid range
        let clampedStart = max(0.0, start)
        let clampedEnd = min(1.0, end)
        let validEnd = max(clampedStart + 0.02, clampedEnd)

        // Send left edge and width directly (no center calculation)
        let leftEdge = clampedStart
        let width = validEnd - clampedStart

        audioUnit.setRegionManualPosition(Int32(region.index), position: leftEdge)
        audioUnit.setRegionManualWidth(Int32(region.index), width: width)
        onUpdate()
    }

    private func updateXYPosition(_ newPos: Float, width: Float) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else { return }
        let clampedPos = max(0, min(1.0 - width, newPos))
        audioUnit.setRegionManualPosition(Int32(region.index), position: clampedPos)
        audioUnit.setRegionManualWidth(Int32(region.index), width: width)
        onUpdate()
    }

    private func updateXYWidth(_ newWidth: Float) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else { return }
        let clampedWidth = max(0.02, min(1.0 - region.startPosition, newWidth))
        audioUnit.setRegionManualPosition(Int32(region.index), position: region.startPosition)
        audioUnit.setRegionManualWidth(Int32(region.index), width: clampedWidth)
        onUpdate()
    }

    private func updateGain(_ value: Float) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit,
              let regionData = audioUnit.getGrainRegion(Int32(region.index)) else {
            return
        }
        regionData.gain = value
        audioUnit.setGrainRegion(Int32(region.index), region: regionData)
        onUpdate()
    }

    private func updateActiveState(_ value: Bool) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit,
              let regionData = audioUnit.getGrainRegion(Int32(region.index)) else {
            return
        }
        regionData.active = value
        audioUnit.setGrainRegion(Int32(region.index), region: regionData)
        onUpdate()
    }

    private func updateJitter(_ value: Float) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }
        audioUnit.setRegionJitter(Int32(region.index), jitter: value)
        onUpdate()
    }

    private func updatePlaybackDirection(_ value: Int) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }
        audioUnit.setRegionPlaybackDirection(Int32(region.index), direction: value)
        onUpdate()
    }

    private func updatePlaybackSpeed(_ value: Float) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }
        audioUnit.setRegionPlaybackSpeed(Int32(region.index), speed: value)
        onUpdate()
    }
}
