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

                // Waveform Display with Position Control
                VStack(alignment: .leading, spacing: 8) {
                    Text("Waveform")
                        .font(.headline)
                    WaveformView(
                        audioUnit: audioUnit,
                        position: Binding(
                            get: { parameterTree.global.position.value },
                            set: { parameterTree.global.position.value = $0 }
                        )
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                // Master
                VStack(alignment: .leading, spacing: 8) {
                    Text("Master")
                        .font(.headline)
                    ParameterSlider(param: parameterTree.global.gain)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                // Grain Parameters
                VStack(alignment: .leading, spacing: 8) {
                    Text("Grain")
                        .font(.headline)
                    ParameterSlider(param: parameterTree.global.grainSize)
                    ParameterSlider(param: parameterTree.global.grainFrequency)
                    ParameterSlider(param: parameterTree.global.position)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)

                // Modulation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Modulation")
                        .font(.headline)
                    ParameterSlider(param: parameterTree.global.pitch)
                    ParameterSlider(param: parameterTree.global.randomness)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            }
            .padding()
        }
    }
}
