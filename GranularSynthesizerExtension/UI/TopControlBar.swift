//
//  TopControlBar.swift
//  GranularSynthesizerExtension
//
//  Compact horizontal control bar
//

import SwiftUI

struct TopControlBar: View {
    var parameterTree: ObservableAUParameterGroup
    var audioUnit: AUAudioUnit?

    @State private var selectedPresetIndex: Int = 0
    @State private var presets: [Preset] = []
    @State private var showingSaveAlert = false
    @State private var newPresetName = ""

    @State private var waveforms: [String] = []
    @State private var selectedWaveformIndex: Int = 0
    @State private var showingFilePicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false

    @State private var attack: Double = 0.01
    @State private var decay: Double = 0.1
    @State private var sustain: Double = 0.7
    @State private var release: Double = 0.2

    private let presetManager = PresetManager.shared

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 8) {
                // Preset Picker (20%)
                CompactPresetPicker(
                    selectedPresetIndex: $selectedPresetIndex,
                    presets: presets,
                    onSelect: { loadPreset($0) },
                    onSave: { showingSaveAlert = true },
                    onDelete: { deleteCurrentPreset() }
                )
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 40)

                // Master Gain (20%)
                CompactParameterSlider(
                    name: "Gain",
                    param: parameterTree.global.gain,
                    width: nil
                )
                .frame(maxWidth: .infinity)

                // ADSR Compact (40%)
                CompactADSRSlider(
                    attack: $attack,
                    decay: $decay,
                    sustain: $sustain,
                    release: $release,
                    width: nil,
                    audioUnit: audioUnit
                )
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 40)

                // Waveform Manager (20%)
                CompactWaveformPicker(
                    waveforms: waveforms,
                    selectedWaveformIndex: $selectedWaveformIndex,
                    onSelect: { selectWaveform($0) },
                    onImport: { showingFilePicker = true }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 60)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(8)
        .onAppear {
            loadPresetsList()
            selectedPresetIndex = presetManager.getCurrentPresetIndex()
            loadWaveforms()
            loadEnvelopeSettings()
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .alert("Save Preset", isPresented: $showingSaveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                saveCurrentPreset()
            }
        } message: {
            TextField("Preset Name", text: $newPresetName)
        }
        .alert("Info", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Preset Management
    private func loadPresetsList() {
        presets = presetManager.getPresets()
    }

    private func loadPreset(_ index: Int) {
        guard let preset = presetManager.getPreset(at: index),
              let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }

        audioUnit.setCurrentWaveform(Int32(preset.waveformIndex))
        audioUnit.setEnvelopeAttack(preset.envelopeAttack)
        audioUnit.setEnvelopeDecay(preset.envelopeDecay)
        audioUnit.setEnvelopeSustain(preset.envelopeSustain)
        audioUnit.setEnvelopeRelease(preset.envelopeRelease)

        for (index, regionPreset) in preset.grainRegions.enumerated() {
            let regionData = regionPreset.toGrainRegionData()
            audioUnit.setGrainRegion(Int32(index), region: regionData)
        }

        presetManager.saveCurrentPresetIndex(index)
        loadEnvelopeSettings()
    }

    private func saveCurrentPreset() {
        guard !newPresetName.isEmpty,
              let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }

        let currentWaveformIndex = audioUnit.getCurrentWaveformIndex()
        let envelopeAttack = audioUnit.getEnvelopeAttack()
        let envelopeDecay = audioUnit.getEnvelopeDecay()
        let envelopeSustain = audioUnit.getEnvelopeSustain()
        let envelopeRelease = audioUnit.getEnvelopeRelease()

        var regionPresetArray: [GrainRegionPreset] = []
        let regionCount = audioUnit.getGrainRegionCount()
        for i in 0..<regionCount {
            if let region = audioUnit.getGrainRegion(i) {
                regionPresetArray.append(GrainRegionPreset.from(region))
            }
        }

        let newPreset = Preset(
            name: newPresetName,
            author: "User",
            waveformIndex: Int(currentWaveformIndex),
            grainRegions: regionPresetArray,
            envelopeAttack: envelopeAttack,
            envelopeDecay: envelopeDecay,
            envelopeSustain: envelopeSustain,
            envelopeRelease: envelopeRelease
        )

        presetManager.addPreset(newPreset)
        loadPresetsList()

        if let newIndex = presets.firstIndex(where: { $0.name == newPresetName }) {
            selectedPresetIndex = newIndex
        }

        newPresetName = ""
    }

    private func deleteCurrentPreset() {
        presetManager.deletePreset(at: selectedPresetIndex)
        loadPresetsList()
        selectedPresetIndex = max(0, selectedPresetIndex - 1)
    }

    // MARK: - Waveform Management
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
        NotificationCenter.default.post(name: NSNotification.Name("WaveformChanged"), object: nil)
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        isLoading = true

        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                isLoading = false
                return
            }

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

        guard let channelData = buffer.floatChannelData else {
            return nil
        }

        let frameLength = Int(buffer.frameLength)
        var samples = [Float](repeating: 0.0, count: frameLength)

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
                alertMessage = "Waveform '\(name)' imported"
                showingAlert = true

                if let newIndex = waveforms.firstIndex(of: name) {
                    selectWaveform(newIndex)
                }
            } else {
                alertMessage = "Failed to import"
                showingAlert = true
            }
        }
    }

    // MARK: - Envelope
    private func loadEnvelopeSettings() {
        guard let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }
        attack = Double(audioUnit.getEnvelopeAttack())
        decay = Double(audioUnit.getEnvelopeDecay())
        sustain = Double(audioUnit.getEnvelopeSustain())
        release = Double(audioUnit.getEnvelopeRelease())
    }
}

// MARK: - Compact Preset Picker
struct CompactPresetPicker: View {
    @Binding var selectedPresetIndex: Int
    var presets: [Preset]
    var onSelect: (Int) -> Void
    var onSave: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Picker("", selection: $selectedPresetIndex) {
                ForEach(0..<presets.count, id: \.self) { index in
                    Text(presets[index].name).tag(index)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedPresetIndex) { newValue in
                onSelect(newValue)
            }

            Button(action: onSave) {
                Image(systemName: "square.and.arrow.down")
                    .font(.caption)
            }
            .disabled(selectedPresetIndex >= presets.count)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .disabled(selectedPresetIndex >= presets.count || presets[safe: selectedPresetIndex]?.author == "Factory")
        }
    }
}

// MARK: - Compact Parameter Slider
struct CompactParameterSlider: View {
    var name: String
    @ObservedObject var param: ObservableAUParameter
    var width: CGFloat? = nil

    var body: some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)

            Slider(
                value: $param.value,
                in: param.min...param.max
            )

            Text("\(param.value, specifier: "%.2f")")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: width ?? .infinity)
    }
}

// MARK: - Compact ADSR Slider
struct CompactADSRSlider: View {
    @Binding var attack: Double
    @Binding var decay: Double
    @Binding var sustain: Double
    @Binding var release: Double
    var width: CGFloat? = nil
    var audioUnit: AUAudioUnit?

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                Text("A")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f", attack))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("D")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f", decay))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("S")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f", sustain))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("R")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f", release))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 4) {
                CompactSlider(value: $attack, range: 0.001...10.0)
                    .onChange(of: attack) { updateAttack(Float($0)) }

                CompactSlider(value: $decay, range: 0.001...10.0)
                    .onChange(of: decay) { updateDecay(Float($0)) }

                CompactSlider(value: $sustain, range: 0...1)
                    .onChange(of: sustain) { updateSustain(Float($0)) }

                CompactSlider(value: $release, range: 0.001...10.0)
                    .onChange(of: release) { updateRelease(Float($0)) }
            }
        }
        .frame(maxWidth: width ?? .infinity)
    }

    private func updateAttack(_ value: Float) {
        (audioUnit as? GranularSynthesizerExtensionAudioUnit)?.setEnvelopeAttack(value)
    }

    private func updateDecay(_ value: Float) {
        (audioUnit as? GranularSynthesizerExtensionAudioUnit)?.setEnvelopeDecay(value)
    }

    private func updateSustain(_ value: Float) {
        (audioUnit as? GranularSynthesizerExtensionAudioUnit)?.setEnvelopeSustain(value)
    }

    private func updateRelease(_ value: Float) {
        (audioUnit as? GranularSynthesizerExtensionAudioUnit)?.setEnvelopeRelease(value)
    }
}

struct CompactSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))

                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)))
            }
            .cornerRadius(2)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let newValue = range.lowerBound + Double(gesture.location.x / geometry.size.width) * (range.upperBound - range.lowerBound)
                        value = max(range.lowerBound, min(range.upperBound, newValue))
                    }
            )
        }
        .frame(height: 6)
    }
}

// MARK: - Compact Waveform Picker
struct CompactWaveformPicker: View {
    var waveforms: [String]
    @Binding var selectedWaveformIndex: Int
    var onSelect: (Int) -> Void
    var onImport: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Picker("", selection: $selectedWaveformIndex) {
                ForEach(0..<waveforms.count, id: \.self) { index in
                    Text(waveforms[index]).tag(index)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedWaveformIndex) { newValue in
                onSelect(newValue)
            }

            Button(action: onImport) {
                Image(systemName: "plus")
                    .font(.caption)
            }
        }
    }
}
