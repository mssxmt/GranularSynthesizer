//
//  Parameters.swift
//  GranularSynthesizerExtension
//
//  Created by MasashiXimoto on 2026/01/02.
//

import Foundation
import AudioToolbox

let GranularSynthesizerExtensionParameterSpecs = ParameterTreeSpec {
    ParameterGroupSpec(identifier: "global", name: "Global") {
        ParameterSpec(
            address: .gain,
            identifier: "gain",
            name: "Output Gain",
            units: .linearGain,
            valueRange: 0.0...1.0,
            defaultValue: 0.5
        )
        ParameterSpec(
            address: .grainSize,
            identifier: "grainSize",
            name: "Grain Size",
            units: .seconds,
            valueRange: 0.001...0.5,
            defaultValue: 0.1
        )
        ParameterSpec(
            address: .grainFrequency,
            identifier: "grainFrequency",
            name: "Grain Frequency",
            units: .hertz,
            valueRange: 1.0...100.0,
            defaultValue: 10.0
        )
        ParameterSpec(
            address: .position,
            identifier: "position",
            name: "Position",
            units: .generic,
            valueRange: 0.0...1.0,
            defaultValue: 0.0
        )
        ParameterSpec(
            address: .pitch,
            identifier: "pitch",
            name: "Pitch",
            units: .generic,
            valueRange: -24.0...24.0,
            defaultValue: 0.0
        )
        ParameterSpec(
            address: .randomness,
            identifier: "randomness",
            name: "Randomness",
            units: .generic,
            valueRange: 0.0...1.0,
            defaultValue: 0.0
        )
    }
}

extension ParameterSpec {
    init(
        address: GranularSynthesizerExtensionParameterAddress,
        identifier: String,
        name: String,
        units: AudioUnitParameterUnit,
        valueRange: ClosedRange<AUValue>,
        defaultValue: AUValue,
        unitName: String? = nil,
        flags: AudioUnitParameterOptions = [AudioUnitParameterOptions.flag_IsWritable, AudioUnitParameterOptions.flag_IsReadable],
        valueStrings: [String]? = nil,
        dependentParameters: [NSNumber]? = nil
    ) {
        self.init(address: address.rawValue,
                  identifier: identifier,
                  name: name,
                  units: units,
                  valueRange: valueRange,
                  defaultValue: defaultValue,
                  unitName: unitName,
                  flags: flags,
                  valueStrings: valueStrings,
                  dependentParameters: dependentParameters)
    }
}
