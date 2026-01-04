//
//  GranularSynthesizerExtensionAudioUnit.h
//  GranularSynthesizerExtension
//
//  Created by MasashiXimoto on 2026/01/02.
//

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

// MARK: - Grain Region Structure

@interface GrainRegionData : NSObject

@property (nonatomic, assign) float startPosition;
@property (nonatomic, assign) float endPosition;
@property (nonatomic, assign) float pitchShift;
@property (nonatomic, assign) float gain;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, assign) float jitter;
@property (nonatomic, assign) NSInteger playbackDirection;  // 0=forward, 1=backward, 2=pingpong, 3=random
@property (nonatomic, assign, readonly) float currentPosition;
@property (nonatomic, assign) float playbackSpeed;

// Per-region LFO settings (for position/width modulation)
@property (nonatomic, assign) BOOL lfoEnabled;
@property (nonatomic, assign) NSInteger lfoWaveform;  // 0=sine, 1=triangle, 2=square, 3=sawtooth, 4=S&H
@property (nonatomic, assign) float lfoFrequency;      // 0.1Hz - 20Hz
@property (nonatomic, assign) float lfoDepth;          // 0.0 - 1.0
@property (nonatomic, assign) NSInteger lfoTarget;     // 0=off, 1=position, 2=width

// Manual setting values (set by XY Pad)
@property (nonatomic, assign) float manualPosition;    // Manual position from XY Pad
@property (nonatomic, assign) float manualWidth;       // Manual width from XY Pad

- (instancetype)initWithStartPosition:(float)startPosition
                           endPosition:(float)endPosition
                            pitchShift:(float)pitchShift
                                  gain:(float)gain
                                active:(BOOL)active
                                jitter:(float)jitter
                    playbackDirection:(NSInteger)playbackDirection
                        playbackSpeed:(float)playbackSpeed;

@end

@interface GranularSynthesizerExtensionAudioUnit : AUAudioUnit
- (void)setupParameterTree:(AUParameterTree *)parameterTree;

// MARK: - Waveform Data Access
- (NSArray<NSNumber *> *)getWaveformData;
- (int)getWaveformSize;

// MARK: - Grain Region Management
- (int)getGrainRegionCount;
- (GrainRegionData *)getGrainRegion:(int)index;
- (void)setGrainRegion:(int)index region:(GrainRegionData *)region;
- (void)setRegionPlaybackDirection:(int)index direction:(NSInteger)direction;
- (void)setRegionJitter:(int)index jitter:(float)jitter;
- (void)setRegionPlaybackSpeed:(int)index speed:(float)speed;
- (float)getRegionPlaybackPosition:(int)index;
- (float)getRegionPlaybackSpeed:(int)index;
- (void)addGrainRegion;
- (void)removeGrainRegion:(int)index;

// MARK: - Region LFO Control (Per-region for position/width modulation)
- (void)setRegionLFOEnabled:(int)index enabled:(BOOL)enabled;
- (void)setRegionLFOWaveform:(int)index waveform:(NSInteger)waveform;
- (void)setRegionLFOFrequency:(int)index frequency:(float)freq;
- (void)setRegionLFODepth:(int)index depth:(float)depth;
- (void)setRegionLFOTarget:(int)index target:(NSInteger)target;
- (BOOL)getRegionLFOEnabled:(int)index;
- (NSInteger)getRegionLFOWaveform:(int)index;
- (float)getRegionLFOFrequency:(int)index;
- (float)getRegionLFODepth:(int)index;
- (NSInteger)getRegionLFOTarget:(int)index;

// MARK: - Manual Position/Width Control (for XY Pad)
- (void)setRegionManualPosition:(int)index position:(float)position;
- (void)setRegionManualWidth:(int)index width:(float)width;
- (float)getRegionManualPosition:(int)index;
- (float)getRegionManualWidth:(int)index;

// MARK: - Region LFO Modulation Values (for UI animation)
- (float)getRegionLFOPositionMod:(int)index;
- (float)getRegionLFOWidthMod:(int)index;

// MARK: - Voice ADSR Envelope Control (Master AMP)
- (void)setEnvelopeAttack:(float)attack;
- (void)setEnvelopeDecay:(float)decay;
- (void)setEnvelopeSustain:(float)sustain;
- (void)setEnvelopeRelease:(float)release;
- (float)getEnvelopeAttack;
- (float)getEnvelopeDecay;
- (float)getEnvelopeSustain;
- (float)getEnvelopeRelease;

// MARK: - Waveform Management
- (int)getWaveformCount;
- (NSString *)getWaveformName:(int)index;
- (int)getCurrentWaveformIndex;
- (void)setCurrentWaveform:(int)index;
- (BOOL)loadWaveform:(NSString *)name data:(const float *)data sampleCount:(int)sampleCount;
- (BOOL)removeWaveform:(int)index;

// MARK: - MIDI Note Control
- (void)noteOn:(int)noteNumber velocity:(float)velocity;
- (void)noteOff:(int)noteNumber;
- (void)allNotesOff;
- (int)getActiveVoiceCount;

@end
