//
//  GranularSynthesizerExtensionAudioUnit.h
//  GranularSynthesizerExtension
//
//  Created by MasashiXimoto on 2026/01/02.
//

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@interface GranularSynthesizerExtensionAudioUnit : AUAudioUnit
- (void)setupParameterTree:(AUParameterTree *)parameterTree;

// MARK: - Waveform Data Access
- (NSArray<NSNumber *> *)getWaveformData;
- (int)getWaveformSize;
@end
