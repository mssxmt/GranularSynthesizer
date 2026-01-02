//
//  WaveformView.swift
//  GranularSynthesizerExtension
//
//  Waveform display with point placement
//

import SwiftUI

struct WaveformView: View {
    var audioUnit: AUAudioUnit?
    @Binding var position: Float

    private static let downsampleFactor = 100  // Render every Nth sample for performance

    @State private var waveformData: [Float] = []
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))

                // Waveform
                if !waveformData.isEmpty {
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        let centerY = height / 2

                        // Downsample and draw waveform
                        for (index, sample) in waveformData.enumerated() {
                            let x = CGFloat(index) / CGFloat(waveformData.count) * width

                            // Scale sample to fit height (with some padding)
                            let y = centerY - (CGFloat(sample) * height * 0.4)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.blue, lineWidth: 1.5)
                }

                // Position indicator line
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2)
                    .position(x: CGFloat(position) * geometry.size.width, y: geometry.size.height / 2)

                // Draggable position handle
                Circle()
                    .fill(Color.red)
                    .frame(width: 20, height: 20)
                    .position(
                        x: CGFloat(position) * geometry.size.width,
                        y: geometry.size.height / 2
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let newPosition = Float(value.location.x / geometry.size.width)
                                position = max(0.0, min(1.0, newPosition))
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
            .onAppear {
                loadWaveform()
            }
        }
        .frame(height: 120)
    }

    private func loadWaveform() {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }

        let size = audioUnit.getWaveformSize()
        guard let fullData = audioUnit.getWaveformData() else {
            return
        }

        // Downsample for performance
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
}
