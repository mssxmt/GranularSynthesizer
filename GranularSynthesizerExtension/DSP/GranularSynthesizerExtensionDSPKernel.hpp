//
//  GranularSynthesizerExtensionDSPKernel.hpp
//  GranularSynthesizerExtension
//
//  Modified for Granular Synthesis
//

#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <CoreMIDI/CoreMIDI.h>
#import <algorithm>
#import <vector>
#import <span>

#import "GranularEngine.hpp"
#import "GranularSynthesizerExtension-Swift.h"
#import "GranularSynthesizerExtensionParameterAddresses.h"

/*
 GranularSynthesizerExtensionDSPKernel
 As a non-ObjC class, this is safe to use from render thread.
 */
class GranularSynthesizerExtensionDSPKernel {
public:
    void initialize(int channelCount, double inSampleRate) {
        mSampleRate = inSampleRate;
        mGranularEngine = GranularEngine(inSampleRate);
    }

    void deInitialize() {
    }

    // MARK: - Bypass
    bool isBypassed() {
        return mBypassed;
    }

    void setBypass(bool shouldBypass) {
        mBypassed = shouldBypass;
    }

    // MARK: - Parameter Getter / Setter
    void setParameter(AUParameterAddress address, AUValue value) {
        switch (address) {
            case GranularSynthesizerExtensionParameterAddress::gain:
                mGain = value;
                break;
            // Global grain parameters removed - now handled per region
            // case GranularSynthesizerExtensionParameterAddress::grainSize:
            // case GranularSynthesizerExtensionParameterAddress::grainFrequency:
            // case GranularSynthesizerExtensionParameterAddress::position:
            // case GranularSynthesizerExtensionParameterAddress::pitch:
            // case GranularSynthesizerExtensionParameterAddress::randomness:
            //     // TODO: These will be handled by region controls
            //     break;
        }
    }

    AUValue getParameter(AUParameterAddress address) {
        switch (address) {
            case GranularSynthesizerExtensionParameterAddress::gain:
                return (AUValue)mGain;
            default:
                return 0.0f;
        }
    }

    // MARK: - Max Frames
    AUAudioFrameCount maximumFramesToRender() const {
        return mMaxFramesToRender;
    }

    void setMaximumFramesToRender(const AUAudioFrameCount &maxFrames) {
        mMaxFramesToRender = maxFrames;
    }

    // MARK: - Musical Context
    void setMusicalContextBlock(AUHostMusicalContextBlock contextBlock) {
        mMusicalContextBlock = contextBlock;
    }

    // MARK: - MIDI Protocol
    MIDIProtocolID AudioUnitMIDIProtocol() const {
        return kMIDIProtocol_2_0;
    }

    /**
     MARK: - Internal Process

     Granular synthesis processing
     */
    void process(std::span<float *> outputBuffers, AUEventSampleTime bufferStartTime, AUAudioFrameCount frameCount) {
        if (mBypassed) {
            // Fill the 'outputBuffers' with silence
            for (UInt32 channel = 0; channel < outputBuffers.size(); ++channel) {
                std::fill_n(outputBuffers[channel], frameCount, 0.f);
            }
            return;
        }

        // Use this to get Musical context info from the Plugin Host
        if (mMusicalContextBlock) {
            mMusicalContextBlock(nullptr /* currentTempo */,
                                 nullptr /* timeSignatureNumerator */,
                                 nullptr /* timeSignatureDenominator */,
                                 nullptr /* currentBeatPosition */,
                                 nullptr /* sampleOffsetToNextBeat */,
                                 nullptr /* currentMeasureDownbeatPosition */);
        }

        // Generate per sample dsp
        for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
            // Process granular engine
            const auto sample = mGranularEngine.process() * mGain;

            for (UInt32 channel = 0; channel < outputBuffers.size(); ++channel) {
                outputBuffers[channel][frameIndex] = sample;
            }
        }
    }

    void handleOneEvent(AUEventSampleTime now, AURenderEvent const *event) {
        switch (event->head.eventType) {
            case AURenderEventParameter: {
                handleParameterEvent(now, event->parameter);
                break;
            }

            case AURenderEventMIDIEventList: {
                handleMIDIEventList(now, &event->MIDIEventsList);
                break;
            }

            default:
                break;
        }
    }

    void handleParameterEvent(AUEventSampleTime now, AUParameterEvent const& parameterEvent) {
        // Implement handling incoming Parameter events as needed
    }

    void handleMIDIEventList(AUEventSampleTime now, AUMIDIEventList const* midiEvent) {
        auto visitor = [] (void* context, MIDITimeStamp timeStamp, MIDIUniversalMessage message) {
            auto thisObject = static_cast<GranularSynthesizerExtensionDSPKernel *>(context);

            switch (message.type) {
                case kMIDIMessageTypeChannelVoice2: {
                    thisObject->handleMIDI2VoiceMessage(message);
                }
                    break;

                default:
                    break;
            }
        };

        MIDIEventListForEachEvent(&midiEvent->eventList, visitor, this);
    }

    void handleMIDI2VoiceMessage(const struct MIDIUniversalMessage& message) {
        // Note On
        if (message.channelVoice2.status == kMIDICVStatusNoteOn) {
            int note = message.channelVoice2.note.number;
            float velocity = message.channelVoice2.note.velocity / 127.0f;
            noteOn(note, velocity);
        }
        // Note Off
        else if (message.channelVoice2.status == kMIDICVStatusNoteOff) {
            int note = message.channelVoice2.note.number;
            noteOff(note);
        }
    }

    // MARK: - MIDI Note Control

    void noteOn(int noteNumber, float velocity) {
        mGranularEngine.noteOn(noteNumber, velocity);
    }

    void noteOff(int noteNumber) {
        mGranularEngine.noteOff(noteNumber);
    }

    void allNotesOff() {
        mGranularEngine.allNotesOff();
    }

    int getActiveVoiceCount() const {
        return mGranularEngine.getActiveVoiceCount();
    }

    // MARK: - Waveform Data Access
    const std::vector<float>& getWaveformData() const {
        return mGranularEngine.getAudioBuffer();
    }

    int getWaveformSize() const {
        return mGranularEngine.getBufferSize();
    }

    // MARK: - Grain Region Management
    int getGrainRegionCount() const {
        return mGranularEngine.getGrainRegionCount();
    }

    GrainRegion getGrainRegion(int index) const {
        return mGranularEngine.getGrainRegion(index);
    }

    void setGrainRegion(int index, const GrainRegion& region) {
        mGranularEngine.setGrainRegion(index, region);
    }

    void setRegionPlaybackDirection(int index, PlaybackDirection direction) {
        mGranularEngine.setRegionPlaybackDirection(index, direction);
    }

    void setRegionJitter(int index, float jitter) {
        mGranularEngine.setRegionJitter(index, jitter);
    }

    void setRegionPlaybackSpeed(int index, float speed) {
        mGranularEngine.setRegionPlaybackSpeed(index, speed);
    }

    float getRegionPlaybackSpeed(int index) const {
        return mGranularEngine.getRegionPlaybackSpeed(index);
    }

    float getRegionPlaybackPosition(int index) const {
        return mGranularEngine.getRegionPlaybackPosition(index);
    }

    void addGrainRegion() {
        mGranularEngine.addGrainRegion();
    }

    void removeGrainRegion(int index) {
        mGranularEngine.removeGrainRegion(index);
    }

    // MARK: - Region LFO Control (Per-region for position/width modulation)

    void setRegionLFOEnabled(int index, bool enabled) {
        mGranularEngine.setRegionLFOEnabled(index, enabled);
    }

    void setRegionLFOWaveform(int index, int waveform) {
        mGranularEngine.setRegionLFOWaveform(index, waveform);
    }

    void setRegionLFOFrequency(int index, float frequency) {
        mGranularEngine.setRegionLFOFrequency(index, frequency);
    }

    void setRegionLFODepth(int index, float depth) {
        mGranularEngine.setRegionLFODepth(index, depth);
    }

    void setRegionLFOTarget(int index, int target) {
        mGranularEngine.setRegionLFOTarget(index, target);
    }

    bool getRegionLFOEnabled(int index) const {
        return mGranularEngine.getRegionLFOEnabled(index);
    }

    int getRegionLFOWaveform(int index) const {
        return mGranularEngine.getRegionLFOWaveform(index);
    }

    float getRegionLFOFrequency(int index) const {
        return mGranularEngine.getRegionLFOFrequency(index);
    }

    float getRegionLFODepth(int index) const {
        return mGranularEngine.getRegionLFODepth(index);
    }

    int getRegionLFOTarget(int index) const {
        return mGranularEngine.getRegionLFOTarget(index);
    }

    // MARK: - Manual Position/Width Control (for XY Pad)

    void setRegionManualPosition(int index, float position) {
        mGranularEngine.setRegionManualPosition(index, position);
    }

    void setRegionManualWidth(int index, float width) {
        mGranularEngine.setRegionManualWidth(index, width);
    }

    float getRegionManualPosition(int index) const {
        return mGranularEngine.getRegionManualPosition(index);
    }

    float getRegionManualWidth(int index) const {
        return mGranularEngine.getRegionManualWidth(index);
    }

    // MARK: - Region LFO Modulation Values (for UI animation)
    float getRegionLFOPositionMod(int index) const {
        return mGranularEngine.getRegionLFOPositionMod(index);
    }

    float getRegionLFOWidthMod(int index) const {
        return mGranularEngine.getRegionLFOWidthMod(index);
    }

    // MARK: - Voice ADSR Envelope Control

    void setEnvelopeAttack(float attack) {
        mGranularEngine.setEnvelopeAttack(attack);
    }

    void setEnvelopeDecay(float decay) {
        mGranularEngine.setEnvelopeDecay(decay);
    }

    void setEnvelopeSustain(float sustain) {
        mGranularEngine.setEnvelopeSustain(sustain);
    }

    void setEnvelopeRelease(float release) {
        mGranularEngine.setEnvelopeRelease(release);
    }

    float getEnvelopeAttack() const {
        return mGranularEngine.getEnvelopeAttack();
    }

    float getEnvelopeDecay() const {
        return mGranularEngine.getEnvelopeDecay();
    }

    float getEnvelopeSustain() const {
        return mGranularEngine.getEnvelopeSustain();
    }

    float getEnvelopeRelease() const {
        return mGranularEngine.getEnvelopeRelease();
    }

    // MARK: - Waveform Management

    int getWaveformCount() const {
        return mGranularEngine.getWaveformCount();
    }

    std::string getWaveformName(int index) const {
        return mGranularEngine.getWaveformName(index);
    }

    int getCurrentWaveformIndex() const {
        return mGranularEngine.getCurrentWaveformIndex();
    }

    void setCurrentWaveform(int index) {
        mGranularEngine.setCurrentWaveform(index);
    }

    bool loadWaveform(const std::string& name, const float* data, int sampleCount) {
        return mGranularEngine.loadWaveform(name, data, sampleCount);
    }

    bool removeWaveform(int index) {
        return mGranularEngine.removeWaveform(index);
    }

    // MARK: - Member Variables
    AUHostMusicalContextBlock mMusicalContextBlock;

    double mSampleRate = 44100.0;
    double mGain = 0.5;

    bool mBypassed = false;
    AUAudioFrameCount mMaxFramesToRender = 1024;

    GranularEngine mGranularEngine;
};
