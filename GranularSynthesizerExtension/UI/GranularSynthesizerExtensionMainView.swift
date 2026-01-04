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
        VStack(spacing: 0) {
            // Title
            Text("Granular Synthesizer")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Top Control Bar (Compact horizontal)
            TopControlBar(parameterTree: parameterTree, audioUnit: audioUnit)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)

            Divider()

            // Main Content: Grain Regions with Waveform
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Grain Regions")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    WaveformView(audioUnit: audioUnit)
                }
            }
        }
    }
}
