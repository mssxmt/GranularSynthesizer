//
//  GranularSynthesizerExtensionAudioUnit.mm
//  GranularSynthesizerExtension
//
//  Created by MasashiXimoto on 2026/01/02.
//

// Import AudioKit frameworks first
#import <AVFoundation/AVFoundation.h>
#import <CoreAudioKit/CoreAudioKit.h>

// Import C++ headers to avoid enum conflicts
#import "GranularSynthesizerExtensionAUProcessHelper.hpp"
#import "GranularSynthesizerExtensionDSPKernel.hpp"

#import "GranularSynthesizerExtensionAudioUnit.h"


// Define parameter addresses.

@interface GranularSynthesizerExtensionAudioUnit ()

@property (nonatomic, readwrite) AUParameterTree *parameterTree;
@property AUAudioUnitBusArray *outputBusArray;
@property (nonatomic, readonly) AUAudioUnitBus *outputBus;
@end


@implementation GranularSynthesizerExtensionAudioUnit {
    // C++ members need to be ivars; they would be copied on access if they were properties.
    GranularSynthesizerExtensionDSPKernel _kernel;
    std::unique_ptr<AUProcessHelper> _processHelper;
}

@synthesize parameterTree = _parameterTree;

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self == nil) { return nil; }
    
    [self setupAudioBuses];
    
    return self;
}

#pragma mark - AUAudioUnit Setup

- (void)setupAudioBuses {
    // Create the output bus first
    AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:2];
    _outputBus = [[AUAudioUnitBus alloc] initWithFormat:format error:nil];
    _outputBus.maximumChannelCount = 8;
    
    // then an array with it
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                             busType:AUAudioUnitBusTypeOutput
                                                              busses: @[_outputBus]];
}

- (void)setupParameterTree:(AUParameterTree *)parameterTree {
    _parameterTree = parameterTree;
    
    // Send the Parameter default values to the Kernel before setting up the parameter callbacks, so that the defaults set in the Kernel.hpp don't propagate back to the AUParameters via GetParameter
    for (AUParameter *param in _parameterTree.allParameters) {
        _kernel.setParameter(param.address, param.value);
    }
    
    [self setupParameterCallbacks];
}

- (void)setupParameterCallbacks {
    // Make a local pointer to the kernel to avoid capturing self.
    
    __block GranularSynthesizerExtensionDSPKernel *kernel = &_kernel;
    
    // implementorValueObserver is called when a parameter changes value.
    _parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        kernel->setParameter(param.address, value);
    };
    
    // implementorValueProvider is called when the value needs to be refreshed.
    _parameterTree.implementorValueProvider = ^(AUParameter *param) {
        return kernel->getParameter(param.address);
    };
    
    // A function to provide string representations of parameter values.
    _parameterTree.implementorStringFromValueCallback = ^(AUParameter *param, const AUValue *__nullable valuePtr) {
        AUValue value = valuePtr == nil ? param.value : *valuePtr;
        
        return [NSString stringWithFormat:@"%.f", value];
    };
}

#pragma mark - AUAudioUnit Overrides

- (AUAudioFrameCount)maximumFramesToRender {
    return _kernel.maximumFramesToRender();
}

- (void)setMaximumFramesToRender:(AUAudioFrameCount)maximumFramesToRender {
    _kernel.setMaximumFramesToRender(maximumFramesToRender);
}

// An audio unit's audio output connection points.
// Subclassers must override this property getter and should return the same object every time.
// See sample code.
- (AUAudioUnitBusArray *)outputBusses {
    return _outputBusArray;
}

- (void)setShouldBypassEffect:(BOOL)shouldBypassEffect {
    _kernel.setBypass(shouldBypassEffect);
}

- (BOOL)shouldBypassEffect {
    return _kernel.isBypassed();
}

// Allocate resources required to render.
// Subclassers should call the superclass implementation.
- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
    const auto outputChannelCount = [self.outputBusses objectAtIndexedSubscript:0].format.channelCount;
    
    _kernel.setMusicalContextBlock(self.musicalContextBlock);
    _kernel.initialize(outputChannelCount, _outputBus.format.sampleRate);
    _processHelper = std::make_unique<AUProcessHelper>(_kernel, outputChannelCount);
    return [super allocateRenderResourcesAndReturnError:outError];
}

// Deallocate resources allocated in allocateRenderResourcesAndReturnError:
// Subclassers should call the superclass implementation.
- (void)deallocateRenderResources {
    
    // Deallocate your resources.
    _kernel.deInitialize();
    
    [super deallocateRenderResources];
}

#pragma mark - MIDI

- (MIDIProtocolID)AudioUnitMIDIProtocol {
    return _kernel.AudioUnitMIDIProtocol();
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

// Block which subclassers must provide to implement rendering.
- (AUInternalRenderBlock)internalRenderBlock {
    /*
     Capture in locals to avoid ObjC member lookups. If "self" is captured in
     render, we're doing it wrong.
     */
    // Specify captured objects are mutable.
    __block GranularSynthesizerExtensionDSPKernel *kernel = &_kernel;
    __block std::unique_ptr<AUProcessHelper> &processHelper = _processHelper;
    
    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags 				*actionFlags,
                              const AudioTimeStamp       				*timestamp,
                              AVAudioFrameCount           				frameCount,
                              NSInteger                   				outputBusNumber,
                              AudioBufferList            				*outputData,
                              const AURenderEvent        				*realtimeEventListHead,
                              AURenderPullInputBlock __unsafe_unretained pullInputBlock) {
        
        if (frameCount > kernel->maximumFramesToRender()) {
            return kAudioUnitErr_TooManyFramesToProcess;
        }
        
        /*
         Important:
         If the caller passed non-null output pointers (outputData->mBuffers[x].mData), use those.
         
         If the caller passed null output buffer pointers, process in memory owned by the Audio Unit
         and modify the (outputData->mBuffers[x].mData) pointers to point to this owned memory.
         The Audio Unit is responsible for preserving the validity of this memory until the next call to render,
         or deallocateRenderResources is called.
         
         If your algorithm cannot process in-place, you will need to preallocate an output buffer
         and use it here.
         
         See the description of the canProcessInPlace property.
         */
        processHelper->processWithEvents(outputData, timestamp, frameCount, realtimeEventListHead);
        
        return noErr;
    };

}

#pragma mark - Waveform Data Access

- (NSArray<NSNumber *> *)getWaveformData {
    const std::vector<float>& waveform = _kernel.getWaveformData();
    NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:waveform.size()];

    for (const float& sample : waveform) {
        [result addObject:@(sample)];
    }

    return [result copy];
}

- (int)getWaveformSize {
    return _kernel.getWaveformSize();
}

#pragma mark - Grain Region Management

- (int)getGrainRegionCount {
    return _kernel.getGrainRegionCount();
}

- (GrainRegionData *)getGrainRegion:(int)index {
    const GrainRegion& region = _kernel.getGrainRegion(index);
    GrainRegionData* data = [[GrainRegionData alloc] initWithStartPosition:region.startPosition
                                                          endPosition:region.endPosition
                                                                 gain:region.gain
                                                               active:region.active
                                                               jitter:region.jitter
                                                   playbackDirection:(NSInteger)region.playbackDirection
                                                       playbackSpeed:region.playbackSpeed];
    // LFO properties
    data.lfoEnabled = region.lfoEnabled;
    data.lfoWaveform = (NSInteger)region.lfoWaveform;
    data.lfoFrequency = region.lfoFrequency;
    data.lfoDepth = region.lfoDepth;
    data.lfoTarget = (NSInteger)region.lfoTarget;
    // Manual values
    data.manualPosition = region.manualPosition;
    data.manualWidth = region.manualWidth;
    return data;
}

- (void)setGrainRegion:(int)index region:(GrainRegionData *)region {
    if (!region) return;

    GrainRegion cppRegion;
    cppRegion.startPosition = region.startPosition;
    cppRegion.endPosition = region.endPosition;
    cppRegion.gain = region.gain;
    cppRegion.active = region.active;
    cppRegion.jitter = region.jitter;
    cppRegion.playbackDirection = (PlaybackDirection)region.playbackDirection;
    cppRegion.playbackSpeed = region.playbackSpeed;

    // LFO properties
    cppRegion.lfoEnabled = region.lfoEnabled;
    cppRegion.lfoWaveform = (int)region.lfoWaveform;
    cppRegion.lfoFrequency = region.lfoFrequency;
    cppRegion.lfoDepth = region.lfoDepth;
    cppRegion.lfoTarget = (int)region.lfoTarget;
    // Manual values
    cppRegion.manualPosition = region.manualPosition;
    cppRegion.manualWidth = region.manualWidth;

    _kernel.setGrainRegion(index, cppRegion);
}

- (void)setRegionPlaybackDirection:(int)index direction:(NSInteger)direction {
    _kernel.setRegionPlaybackDirection(index, (PlaybackDirection)direction);
}

- (void)setRegionJitter:(int)index jitter:(float)jitter {
    _kernel.setRegionJitter(index, jitter);
}

- (void)setRegionGain:(int)index gain:(float)gain {
    _kernel.setRegionGain(index, gain);
}

- (void)setRegionPlaybackSpeed:(int)index speed:(float)speed {
    _kernel.setRegionPlaybackSpeed(index, speed);
}

- (float)getRegionPlaybackSpeed:(int)index {
    return _kernel.getRegionPlaybackSpeed(index);
}

- (float)getRegionPlaybackPosition:(int)index {
    return _kernel.getRegionPlaybackPosition(index);
}

- (void)addGrainRegion {
    _kernel.addGrainRegion();
}

- (void)removeGrainRegion:(int)index {
    _kernel.removeGrainRegion(index);
}

#pragma mark - Region LFO Control

- (void)setRegionLFOEnabled:(int)index enabled:(BOOL)enabled {
    _kernel.setRegionLFOEnabled(index, enabled);
}

- (void)setRegionLFOWaveform:(int)index waveform:(NSInteger)waveform {
    _kernel.setRegionLFOWaveform(index, (int)waveform);
}

- (void)setRegionLFOFrequency:(int)index frequency:(float)freq {
    _kernel.setRegionLFOFrequency(index, freq);
}

- (void)setRegionLFODepth:(int)index depth:(float)depth {
    _kernel.setRegionLFODepth(index, depth);
}

- (void)setRegionLFOTarget:(int)index target:(NSInteger)target {
    _kernel.setRegionLFOTarget(index, (int)target);
}

- (BOOL)getRegionLFOEnabled:(int)index {
    return _kernel.getRegionLFOEnabled(index);
}

- (NSInteger)getRegionLFOWaveform:(int)index {
    return (NSInteger)_kernel.getRegionLFOWaveform(index);
}

- (float)getRegionLFOFrequency:(int)index {
    return _kernel.getRegionLFOFrequency(index);
}

- (float)getRegionLFODepth:(int)index {
    return _kernel.getRegionLFODepth(index);
}

- (NSInteger)getRegionLFOTarget:(int)index {
    return (NSInteger)_kernel.getRegionLFOTarget(index);
}

#pragma mark - Manual Position/Width Control

- (void)setRegionManualPosition:(int)index position:(float)position {
    _kernel.setRegionManualPosition(index, position);
}

- (void)setRegionManualWidth:(int)index width:(float)width {
    _kernel.setRegionManualWidth(index, width);
}

- (float)getRegionManualPosition:(int)index {
    return _kernel.getRegionManualPosition(index);
}

- (float)getRegionManualWidth:(int)index {
    return _kernel.getRegionManualWidth(index);
}

#pragma mark - Voice ADSR Envelope Control

- (void)setEnvelopeAttack:(float)attack {
    _kernel.setEnvelopeAttack(attack);
}

- (void)setEnvelopeDecay:(float)decay {
    _kernel.setEnvelopeDecay(decay);
}

- (void)setEnvelopeSustain:(float)sustain {
    _kernel.setEnvelopeSustain(sustain);
}

- (void)setEnvelopeRelease:(float)release {
    _kernel.setEnvelopeRelease(release);
}

- (float)getEnvelopeAttack {
    return _kernel.getEnvelopeAttack();
}

- (float)getEnvelopeDecay {
    return _kernel.getEnvelopeDecay();
}

- (float)getEnvelopeSustain {
    return _kernel.getEnvelopeSustain();
}

- (float)getEnvelopeRelease {
    return _kernel.getEnvelopeRelease();
}

#pragma mark - MIDI Base Pitch Control

- (void)setBasePitch:(float)pitch {
    _kernel.setBasePitch(pitch);
}

- (float)getBasePitch {
    return _kernel.getBasePitch();
}

#pragma mark - Waveform Management

- (int)getWaveformCount {
    return _kernel.getWaveformCount();
}

- (NSString *)getWaveformName:(int)index {
    std::string name = _kernel.getWaveformName(index);
    return [NSString stringWithUTF8String:name.c_str()];
}

- (int)getCurrentWaveformIndex {
    return _kernel.getCurrentWaveformIndex();
}

- (void)setCurrentWaveform:(int)index {
    _kernel.setCurrentWaveform(index);
}

- (BOOL)loadWaveform:(NSString *)name data:(const float *)data sampleCount:(int)sampleCount {
    std::string nameStr = [name UTF8String];
    return _kernel.loadWaveform(nameStr, data, sampleCount);
}

- (BOOL)removeWaveform:(int)index {
    return _kernel.removeWaveform(index);
}

#pragma mark - MIDI Note Control

- (void)noteOn:(int)noteNumber velocity:(float)velocity {
    _kernel.noteOn(noteNumber, velocity);
}

- (void)noteOff:(int)noteNumber {
    _kernel.noteOff(noteNumber);
}

- (void)allNotesOff {
    _kernel.allNotesOff();
}

- (int)getActiveVoiceCount {
    return _kernel.getActiveVoiceCount();
}

#pragma mark - Region LFO Modulation Values (for UI animation)

- (float)getRegionLFOPositionMod:(int)index {
    return _kernel.getRegionLFOPositionMod(index);
}

- (float)getRegionLFOWidthMod:(int)index {
    return _kernel.getRegionLFOWidthMod(index);
}

@end

// MARK: - GrainRegionData Implementation

@implementation GrainRegionData

- (instancetype)initWithStartPosition:(float)startPosition
                           endPosition:(float)endPosition
                                  gain:(float)gain
                                active:(BOOL)active
                                jitter:(float)jitter
                    playbackDirection:(NSInteger)playbackDirection
                        playbackSpeed:(float)playbackSpeed {
    self = [super init];
    if (self) {
        _startPosition = startPosition;
        _endPosition = endPosition;
        _gain = gain;
        _active = active;
        _jitter = jitter;
        _playbackDirection = playbackDirection;
        _playbackSpeed = playbackSpeed;
        _currentPosition = startPosition;  // Initialize current position

        // LFO properties (defaults)
        _lfoEnabled = NO;
        _lfoWaveform = 0;          // sine
        _lfoFrequency = 1.0f;
        _lfoDepth = 0.5f;
        _lfoTarget = 0;            // off

        // Manual values (defaults)
        _manualPosition = startPosition;
        _manualWidth = endPosition - startPosition;
    }
    return self;
}

@end

