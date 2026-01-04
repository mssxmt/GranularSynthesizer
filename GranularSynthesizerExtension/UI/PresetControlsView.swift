//
//  PresetControlsView.swift
//  GranularSynthesizerExtension
//
//  Preset Management UI
//

import SwiftUI

struct PresetControlsView: View {
    var audioUnit: AUAudioUnit?

    @State private var selectedPresetIndex: Int = 0
    @State private var presets: [Preset] = []
    @State private var showingSaveAlert = false
    @State private var newPresetName = ""
    @State private var showingDeleteConfirmation = false

    private let presetManager = PresetManager.shared

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Presets")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()
            }

            Divider()

            // Preset Picker
            HStack {
                Text("Preset")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)

                Picker("", selection: $selectedPresetIndex) {
                    ForEach(0..<presets.count, id: \.self) { index in
                        Text(presets[index].name).tag(index)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedPresetIndex) { newValue in
                    loadPreset(newValue)
                }

                Spacer()

                // Save button
                Button(action: {
                    showingSaveAlert = true
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.caption)
                }
                .disabled(selectedPresetIndex >= presets.count)

                // Delete button (only for user presets)
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .disabled(selectedPresetIndex >= presets.count || presets[safe: selectedPresetIndex]?.author == "Factory")
            }

            // Preset Info
            if selectedPresetIndex < presets.count {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Author: \(presets[selectedPresetIndex].author)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Date: \(presets[selectedPresetIndex].date, formatter: dateFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(10)
        .onAppear {
            loadPresetsList()
            selectedPresetIndex = presetManager.getCurrentPresetIndex()
        }
        .alert("Save Preset", isPresented: $showingSaveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                saveCurrentPreset()
            }
        } message: {
            TextField("Preset Name", text: $newPresetName)
        }
        .alert("Delete Preset", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteCurrentPreset()
            }
        } message: {
            Text("Are you sure you want to delete this preset?")
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }

    private func loadPresetsList() {
        presets = presetManager.getPresets()
    }

    private func loadPreset(_ index: Int) {
        guard let preset = presetManager.getPreset(at: index),
              let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }

        // Load waveform selection
        audioUnit.setCurrentWaveform(Int32(preset.waveformIndex))

        // Load LFO settings
        audioUnit.setLFOModulationEnabled(preset.lfoEnabled)
        audioUnit.setLFOFrequency(preset.lfoFrequency)
        audioUnit.setLFOWaveform(Int32(preset.lfoWaveform))
        audioUnit.setLFOTarget(Int32(preset.lfoTarget))
        audioUnit.setLFODepth(preset.lfoDepth)

        // Load Voice ADSR settings
        audioUnit.setEnvelopeAttack(preset.envelopeAttack)
        audioUnit.setEnvelopeDecay(preset.envelopeDecay)
        audioUnit.setEnvelopeSustain(preset.envelopeSustain)
        audioUnit.setEnvelopeRelease(preset.envelopeRelease)

        // Load grain regions
        for (index, regionPreset) in preset.grainRegions.enumerated() {
            let regionData = regionPreset.toGrainRegionData()
            audioUnit.setGrainRegion(Int32(index), region: regionData)
        }

        presetManager.saveCurrentPresetIndex(index)
    }

    private func saveCurrentPreset() {
        guard !newPresetName.isEmpty,
              let audioUnit = audioUnit as? GranularSynthesizerExtensionAudioUnit else {
            return
        }

        // Get current waveform index
        let currentWaveformIndex = audioUnit.getCurrentWaveformIndex()

        // Gather current settings
        let lfoEnabled = audioUnit.getLFOModulationEnabled()
        let lfoTarget = audioUnit.getLFOTarget()
        let lfoDepth = audioUnit.getLFODepth()

        let envelopeAttack = audioUnit.getEnvelopeAttack()
        let envelopeDecay = audioUnit.getEnvelopeDecay()
        let envelopeSustain = audioUnit.getEnvelopeSustain()
        let envelopeRelease = audioUnit.getEnvelopeRelease()

        // Get grain regions
        var regionPresetArray: [GrainRegionPreset] = []
        let regionCount = audioUnit.getGrainRegionCount()
        for i in 0..<regionCount {
            if let region = audioUnit.getGrainRegion(i) {
                regionPresetArray.append(GrainRegionPreset.from(region))
            }
        }

        // Create new preset
        let newPreset = Preset(
            name: newPresetName,
            author: "User",
            waveformIndex: Int(currentWaveformIndex),
            grainRegions: regionPresetArray,
            lfoEnabled: lfoEnabled,
            lfoFrequency: 1.0, // Would need getter
            lfoWaveform: 0, // Would need getter
            lfoTarget: Int(lfoTarget),
            lfoDepth: lfoDepth,
            envelopeAttack: envelopeAttack,
            envelopeDecay: envelopeDecay,
            envelopeSustain: envelopeSustain,
            envelopeRelease: envelopeRelease
        )

        presetManager.addPreset(newPreset)
        loadPresetsList()

        // Select the new preset
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
}

// Helper for safe array access
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
