//
//  GranularSynthesizerApp.swift
//  GranularSynthesizer
//
//  Created by MasashiXimoto on 2026/01/02.
//

import CoreMIDI
import SwiftUI

@main
struct GranularSynthesizerApp: App {
    @ObservedObject private var hostModel = AudioUnitHostModel()

    var body: some Scene {
        WindowGroup {
            ContentView(hostModel: hostModel)
        }
    }
}
