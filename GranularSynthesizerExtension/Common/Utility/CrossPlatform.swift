//
//  CrossPlatform.swift
//  GranularSynthesizerExtension
//
//  Created by MasashiXimoto on 2026/01/02.
//

import Foundation
import SwiftUI

#if os(iOS)
typealias HostingController = UIHostingController
#elseif os(macOS)
typealias HostingController = NSHostingController

extension NSView {
	
	func bringSubviewToFront(_ view: NSView) {
		// This function is a no-opp for macOS
	}
}
#endif
