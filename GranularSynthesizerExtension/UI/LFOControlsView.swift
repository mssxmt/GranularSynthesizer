//
//  LFOControlsView.swift
//  GranularSynthesizerExtension
//
//  LFO Modulation Controls
//

import SwiftUI

struct LFOControlsView: View {
    var audioUnit: AUAudioUnit?

    @State private var enabled = false
    @State private var frequency: Double = 1.0
    @State private var waveform: Int = 0
    @State private var target: Int = 0
    @State private var depth: Double = 0.5

    private let waveformNames = ["Sine", "Triangle", "Square", "Sawtooth", "S&H"]
    private let targetNames = ["Grain Size", "Frequency", "Randomness", "Pitch"]

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("LFO Modulation")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .onChange(of: enabled) { newValue in
                        updateEnabled(newValue)
                    }
            }

            if enabled {
                Divider()

                // Waveform Selection
                HStack {
                    Text("Waveform")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)

                    Picker("", selection: $waveform) {
                        ForEach(0..<waveformNames.count, id: \.self) { i in
                            Text(waveformNames[i]).tag(i)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: waveform) { newValue in
                        updateWaveform(newValue)
                    }
                }

                // Frequency
                HStack {
                    Text("Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)
                    Slider(
                        value: $frequency,
                        in: 0.1...20,
                        step: 0.1
                    ) {
                        Text("Rate Hz")
                    }
                    .onChange(of: frequency) { newValue in
                        updateFrequency(Float(newValue))
                    }
                    Text(String(format: "%.1f Hz", frequency))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }

                // Target Parameter
                HStack {
                    Text("Target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)

                    Picker("", selection: $target) {
                        ForEach(0..<targetNames.count, id: \.self) { i in
                            Text(targetNames[i]).tag(i)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: target) { newValue in
                        updateTarget(newValue)
                    }
                }

                // Depth
                HStack {
                    Text("Depth")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)
                    Slider(
                        value: $depth,
                        in: 0...1
                    ) {
                        Text("Modulation Depth")
                    }
                    .onChange(of: depth) { newValue in
                        updateDepth(Float(newValue))
                    }
                    Text(String(format: "%.2f", depth))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .onAppear {
            loadSettings()
        }
    }

    private func loadSettings() {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }
        enabled = audioUnit.getLFOModulationEnabled()
        target = Int(audioUnit.getLFOTarget())
        depth = Double(audioUnit.getLFODepth())
    }

    private func updateEnabled(_ value: Bool) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }
        audioUnit.setLFOModulationEnabled(value)
    }

    private func updateFrequency(_ value: Float) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }
        audioUnit.setLFOFrequency(value)
    }

    private func updateWaveform(_ value: Int) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }
        audioUnit.setLFOWaveform(Int32(value))
    }

    private func updateTarget(_ value: Int) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }
        audioUnit.setLFOTarget(Int32(value))
    }

    private func updateDepth(_ value: Float) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }
        audioUnit.setLFODepth(value)
    }
}
