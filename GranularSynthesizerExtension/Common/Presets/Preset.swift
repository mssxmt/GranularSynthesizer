//
//  Preset.swift
//  GranularSynthesizerExtension
//
//  Preset Management System
//

import Foundation

// MARK: - Grain Region Data (Codable version)

struct GrainRegionPreset: Codable {
    var startPosition: Float
    var endPosition: Float
    var gain: Float
    var active: Bool
    var jitter: Float
    var playbackDirection: Int
    var playbackSpeed: Float

    // LFO parameters (per-region for position/width modulation)
    var lfoEnabled: Bool = false
    var lfoWaveform: Int = 0          // 0=sine, 1=triangle, 2=square, 3=sawtooth, 4=S&H
    var lfoFrequency: Float = 1.0     // 0.1Hz - 20Hz
    var lfoDepth: Float = 0.5         // 0.0 - 1.0
    var lfoTarget: Int = 0            // 0=off, 1=position, 2=width

    // Manual setting values (set by XY Pad)
    var manualPosition: Float = 0.0
    var manualWidth: Float = 0.25

    static func from(_ region: GrainRegionData) -> GrainRegionPreset {
        return GrainRegionPreset(
            startPosition: region.startPosition,
            endPosition: region.endPosition,
            gain: region.gain,
            active: region.active,
            jitter: region.jitter,
            playbackDirection: region.playbackDirection,
            playbackSpeed: region.playbackSpeed,
            lfoEnabled: region.lfoEnabled,
            lfoWaveform: region.lfoWaveform,
            lfoFrequency: region.lfoFrequency,
            lfoDepth: region.lfoDepth,
            lfoTarget: region.lfoTarget,
            manualPosition: region.manualPosition,
            manualWidth: region.manualWidth
        )
    }

    func toGrainRegionData() -> GrainRegionData {
        let data = GrainRegionData(
            startPosition: startPosition,
            endPosition: endPosition,
            gain: gain,
            active: active,
            jitter: jitter,
            playbackDirection: playbackDirection,
            playbackSpeed: playbackSpeed
        )!
        // LFO properties
        data.lfoEnabled = lfoEnabled
        data.lfoWaveform = lfoWaveform
        data.lfoFrequency = lfoFrequency
        data.lfoDepth = lfoDepth
        data.lfoTarget = lfoTarget
        // Manual values
        data.manualPosition = manualPosition
        data.manualWidth = manualWidth
        return data
    }
}

// MARK: - Preset Data Structure

struct Preset: Codable {
    var name: String
    var author: String
    var date: Date

    // Waveform selection
    var waveformIndex: Int

    // Grain regions (each region has its own grain parameters)
    var grainRegions: [GrainRegionPreset]

    // Master AMP envelope (ADSR)
    var envelopeAttack: Float
    var envelopeDecay: Float
    var envelopeSustain: Float
    var envelopeRelease: Float

    init(
        name: String,
        author: String = "User",
        waveformIndex: Int = 0,
        grainRegions: [GrainRegionPreset] = [],
        envelopeAttack: Float = 0.01,
        envelopeDecay: Float = 0.1,
        envelopeSustain: Float = 0.7,
        envelopeRelease: Float = 0.2
    ) {
        self.name = name
        self.author = author
        self.date = Date()
        self.waveformIndex = waveformIndex
        self.grainRegions = grainRegions
        self.envelopeAttack = envelopeAttack
        self.envelopeDecay = envelopeDecay
        self.envelopeSustain = envelopeSustain
        self.envelopeRelease = envelopeRelease
    }
}

// MARK: - Preset Manager

class PresetManager {
    static let shared = PresetManager()

    private let userDefaultsKey = "GranularSynthesizerPresets"
    private let currentPresetKey = "GranularSynthesizerCurrentPreset"

    private var presets: [Preset] = []

    private init() {
        loadPresets()
    }

    // MARK: - Factory Presets

    static let factoryPresets: [Preset] = [
        Preset(
            name: "Init",
            author: "Factory",
            grainRegions: [
                GrainRegionPreset(startPosition: 0.0, endPosition: 0.25, gain: 1.0, active: true, jitter: 0.0, playbackDirection: 0, playbackSpeed: 0.0000227)
            ],
            envelopeAttack: 0.01,
            envelopeDecay: 0.1,
            envelopeSustain: 0.7,
            envelopeRelease: 0.2
        ),
        Preset(
            name: "Sparse Texture",
            author: "Factory",
            grainRegions: [
                GrainRegionPreset(startPosition: 0.0, endPosition: 0.5, gain: 0.7, active: true, jitter: 0.1, playbackDirection: 0, playbackSpeed: 0.0000227)
            ],
            envelopeAttack: 0.01,
            envelopeDecay: 0.1,
            envelopeSustain: 0.7,
            envelopeRelease: 0.2
        ),
        Preset(
            name: "Dense Cloud",
            author: "Factory",
            grainRegions: [
                GrainRegionPreset(startPosition: 0.0, endPosition: 1.0, gain: 0.5, active: true, jitter: 0.2, playbackDirection: 0, playbackSpeed: 0.0000227)
            ],
            envelopeAttack: 0.01,
            envelopeDecay: 0.1,
            envelopeSustain: 0.7,
            envelopeRelease: 0.2
        ),
        Preset(
            name: "LFO Pulse",
            author: "Factory",
            grainRegions: [
                GrainRegionPreset(startPosition: 0.2, endPosition: 0.8, gain: 0.8, active: true, jitter: 0.0, playbackDirection: 0, playbackSpeed: 0.0000227)
            ],
            envelopeAttack: 0.01,
            envelopeDecay: 0.1,
            envelopeSustain: 0.7,
            envelopeRelease: 0.2
        ),
        Preset(
            name: "Slow Attack",
            author: "Factory",
            grainRegions: [
                GrainRegionPreset(startPosition: 0.0, endPosition: 0.5, gain: 0.6, active: true, jitter: 0.05, playbackDirection: 0, playbackSpeed: 0.0000227)
            ],
            envelopeAttack: 0.5,
            envelopeDecay: 0.3,
            envelopeSustain: 0.8,
            envelopeRelease: 1.0
        ),
        Preset(
            name: "Chaotic Glitch",
            author: "Factory",
            grainRegions: [
                GrainRegionPreset(startPosition: 0.0, endPosition: 1.0, gain: 0.5, active: true, jitter: 0.8, playbackDirection: 3, playbackSpeed: 0.0000227)
            ],
            envelopeAttack: 0.001,
            envelopeDecay: 0.05,
            envelopeSustain: 0.3,
            envelopeRelease: 0.1
        )
    ]

    // MARK: - Load/Save

    func loadPresets() {
        // Start with factory presets
        presets = Self.factoryPresets

        // Load user presets from UserDefaults
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let userPresets = try? JSONDecoder().decode([Preset].self, from: data) {
            presets.append(contentsOf: userPresets)
        }
    }

    func saveUserPresets() {
        let userPresets = presets.filter { !$0.author.isEmpty && $0.author != "Factory" }
        if let data = try? JSONEncoder().encode(userPresets) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    // MARK: - Preset Management

    func getPresets() -> [Preset] {
        return presets
    }

    func getPreset(at index: Int) -> Preset? {
        guard index >= 0 && index < presets.count else { return nil }
        return presets[index]
    }

    func addPreset(_ preset: Preset) {
        presets.append(preset)
        saveUserPresets()
    }

    func updatePreset(at index: Int, preset: Preset) {
        guard index >= 0 && index < presets.count else { return }
        presets[index] = preset
        saveUserPresets()
    }

    func deletePreset(at index: Int) {
        guard index >= 0 && index < presets.count else { return }
        // Don't allow deleting factory presets
        if presets[index].author == "Factory" {
            return
        }
        presets.remove(at: index)
        saveUserPresets()
    }

    func saveCurrentPresetIndex(_ index: Int) {
        UserDefaults.standard.set(index, forKey: currentPresetKey)
    }

    func getCurrentPresetIndex() -> Int {
        return UserDefaults.standard.integer(forKey: currentPresetKey)
    }
}
