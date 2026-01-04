//
//  WaveformManagerView.swift
//  GranularSynthesizerExtension
//
//  Waveform Management UI
//

import SwiftUI
import UniformTypeIdentifiers

struct WaveformManagerView: View {
    var audioUnit: AUAudioUnit?

    @State private var waveforms: [String] = []
    @State private var selectedWaveformIndex: Int = 0
    @State private var showingFilePicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Waveforms")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    showingFilePicker = true
                }) {
                    Image(systemName: "plus")
                        .font(.caption)
                }
            }

            Divider()

            // Waveform List
            if waveforms.isEmpty {
                Text("No waveforms loaded")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(0..<waveforms.count, id: \.self) { index in
                        HStack {
                            HStack {
                                Image(systemName: selectedWaveformIndex == index ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedWaveformIndex == index ? .blue : .secondary)

                                Text(waveforms[index])
                                    .font(.caption)
                                    .foregroundColor(.primary)

                                if index == 0 {
                                    Text("(Built-in)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            // Select button
                            if selectedWaveformIndex != index {
                                Button("Select") {
                                    selectWaveform(index)
                                }
                                .font(.caption)
                            }

                            // Delete button (only for non-built-in waveforms)
                            if index > 0 {
                                Button(action: {
                                    deleteWaveform(index)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Divider()

            // Info text
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import audio files to use as grain source")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Supported: WAV, AIFF, MP3, M4A")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(10)
        .onAppear {
            loadWaveforms()
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .alert("Info", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    private func loadWaveforms() {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }

        let count = audioUnit.getWaveformCount()
        waveforms = []
        for i in 0..<count {
            if let name = audioUnit.getWaveformName(i) {
                waveforms.append(name)
            }
        }
        selectedWaveformIndex = Int(audioUnit.getCurrentWaveformIndex())
    }

    private func selectWaveform(_ index: Int) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }

        audioUnit.setCurrentWaveform(Int32(index))
        selectedWaveformIndex = index

        // Force waveform view to refresh
        NotificationCenter.default.post(name: NSNotification.Name("WaveformChanged"), object: nil)
    }

    private func deleteWaveform(_ index: Int) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }

        let success = audioUnit.removeWaveform(Int32(index))
        if success {
            loadWaveforms()
            alertMessage = "Waveform deleted"
            showingAlert = true
        } else {
            alertMessage = "Cannot delete waveform"
            showingAlert = true
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        isLoading = true

        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                isLoading = false
                return
            }

            // Start accessing the file
            guard url.startAccessingSecurityScopedResource() else {
                alertMessage = "Cannot access file"
                showingAlert = true
                isLoading = false
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                defer {
                    url.stopAccessingSecurityScopedResource()
                    DispatchQueue.main.async {
                        isLoading = false
                    }
                }

                // Load audio file
                if let audioData = self.loadAudioFile(url: url) {
                    DispatchQueue.main.async {
                        self.importWaveform(name: url.deletingPathExtension().lastPathComponent, data: audioData)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.alertMessage = "Failed to load audio file"
                        self.showingAlert = true
                    }
                }
            }

        case .failure(let error):
            alertMessage = "Error: \(error.localizedDescription)"
            showingAlert = true
            isLoading = false
        }
    }

    private func loadAudioFile(url: URL) -> [Float]? {
        // Use AVAudioFile to load the audio
        let avAudioFile: AVAudioFile
        do {
            avAudioFile = try AVAudioFile(forReading: url)
        } catch {
            return nil
        }

        let format = avAudioFile.processingFormat
        let frameCount = UInt32(avAudioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        do {
            try avAudioFile.read(into: buffer)
        } catch {
            return nil
        }

        // Convert to float array
        guard let channelData = buffer.floatChannelData else {
            return nil
        }

        let frameLength = Int(buffer.frameLength)
        var samples = [Float](repeating: 0.0, count: frameLength)

        // Use first channel (mono) or average of stereo
        let firstChannel = channelData[0]
        for i in 0..<frameLength {
            samples[i] = firstChannel[i]
        }

        return samples
    }

    private func importWaveform(name: String, data: [Float]) {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }

        data.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                alertMessage = "Failed to import waveform"
                showingAlert = true
                return
            }
            let success = audioUnit.loadWaveform(name, data: baseAddress, sampleCount: Int32(data.count))
            if success {
                loadWaveforms()
                alertMessage = "Waveform '\(name)' imported successfully"
                showingAlert = true

                // Auto-select the imported waveform
                if let newIndex = waveforms.firstIndex(of: name) {
                    selectWaveform(newIndex)
                }
            } else {
                alertMessage = "Failed to import waveform"
                showingAlert = true
            }
        }
    }
}
