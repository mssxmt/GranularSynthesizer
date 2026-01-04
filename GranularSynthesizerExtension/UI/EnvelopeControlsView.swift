//
//  EnvelopeControlsView.swift
//  GranularSynthesizerExtension
//
//  Voice ADSR Envelope Controls
//

import SwiftUI

struct EnvelopeControlsView: View {
    var audioUnit: AUAudioUnit?

    @State private var attack: Double = 0.01
    @State private var decay: Double = 0.1
    @State private var sustain: Double = 0.7
    @State private var release: Double = 0.2

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Envelope (ADSR)")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()
            }

            Divider()

            // ADSR Sliders
            HStack {
                Text("Attack")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)
                Slider(
                    value: $attack,
                    in: 0.001...10.0,
                    step: 0.001
                ) {
                    Text("Attack Time")
                }
                .onChange(of: attack) { newValue in
                    updateAttack(Float(newValue))
                }
                Text(String(format: "%.3f s", attack))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }

            HStack {
                Text("Decay")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)
                Slider(
                    value: $decay,
                    in: 0.001...10.0,
                    step: 0.001
                ) {
                    Text("Decay Time")
                }
                .onChange(of: decay) { newValue in
                    updateDecay(Float(newValue))
                }
                Text(String(format: "%.3f s", decay))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }

            HStack {
                Text("Sustain")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)
                Slider(
                    value: $sustain,
                    in: 0...1
                ) {
                    Text("Sustain Level")
                }
                .onChange(of: sustain) { newValue in
                    updateSustain(Float(newValue))
                }
                Text(String(format: "%.2f", sustain))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }

            HStack {
                Text("Release")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)
                Slider(
                    value: $release,
                    in: 0.001...10.0,
                    step: 0.001
                ) {
                    Text("Release Time")
                }
                .onChange(of: release) { newValue in
                    updateRelease(Float(newValue))
                }
                Text(String(format: "%.3f s", release))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }

            Divider()

            // Info text
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amplitude envelope for each voice")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Attack, Decay, Sustain, Release")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
        .onAppear {
            loadSettings()
        }
    }

    private func loadSettings() {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }
        attack = Double(audioUnit.getEnvelopeAttack())
        decay = Double(audioUnit.getEnvelopeDecay())
        sustain = Double(audioUnit.getEnvelopeSustain())
        release = Double(audioUnit.getEnvelopeRelease())
    }

    private func updateAttack(_ value: Float) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }
        audioUnit.setEnvelopeAttack(value)
    }

    private func updateDecay(_ value: Float) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }
        audioUnit.setEnvelopeDecay(value)
    }

    private func updateSustain(_ value: Float) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }
        audioUnit.setEnvelopeSustain(value)
    }

    private func updateRelease(_ value: Float) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }
        audioUnit.setEnvelopeRelease(value)
    }
}
