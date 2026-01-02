//
//  AudioUnitViewModel.swift
//  GranularSynthesizer
//
//  Created by MasashiXimoto on 2026/01/02.
//

import SwiftUI
import AudioToolbox
import CoreAudioKit

struct AudioUnitViewModel {
    var showAudioControls: Bool = false
    var showMIDIContols: Bool = false
    var title: String = "-"
    var message: String = "No Audio Unit loaded.."
    var viewController: ViewController?
}
