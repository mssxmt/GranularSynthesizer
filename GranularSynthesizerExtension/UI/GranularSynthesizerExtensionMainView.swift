//
//  GranularSynthesizerExtensionMainView.swift
//  GranularSynthesizerExtension
//
//  Modified for Granular Synthesis
//

import SwiftUI
import AudioToolbox

struct GranularSynthesizerExtensionMainView: View {
    var parameterTree: ObservableAUParameterGroup
    var audioUnit: AUAudioUnit?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Granular Synthesizer")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom)

                // Preset Management
                PresetControlsView(audioUnit: audioUnit)
                    .padding()

                // Waveform Display with Grain Regions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Grain Regions")
                        .font(.headline)
                    WaveformView(audioUnit: audioUnit)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                // Waveform Management
                WaveformManagerView(audioUnit: audioUnit)
                    .padding()

                // Master
                VStack(alignment: .leading, spacing: 8) {
                    Text("Master")
                        .font(.headline)
                    ParameterSlider(param: parameterTree.global.gain)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                // Envelope Modulation
                EnvelopeControlsView(audioUnit: audioUnit)
                    .padding()
            }
            .padding()
        }
    }
}
