//
//  GranularSynthesizerExtensionMainView.swift
//  GranularSynthesizerExtension
//
//  Created by MasashiXimoto on 2026/01/02.
//

import SwiftUI

struct GranularSynthesizerExtensionMainView: View {
    var parameterTree: ObservableAUParameterGroup
    
    var body: some View {
        ParameterSlider(param: parameterTree.global.gain)
    }
}
