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
            case GranularSynthesizerExtensionParameterAddress::grainSize:
                mGranularEngine.setGrainSize(value);
                break;
            case GranularSynthesizerExtensionParameterAddress::grainFrequency:
                mGranularEngine.setGrainFrequency(value);
                break;
            case GranularSynthesizerExtensionParameterAddress::position:
                mGranularEngine.setPosition(value);
                break;
            case GranularSynthesizerExtensionParameterAddress::pitch:
                mGranularEngine.setPitch(value);
                break;
            case GranularSynthesizerExtensionParameterAddress::randomness:
                mGranularEngine.setRandomness(value);
                break;
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
        // Note On: Always enable granular engine
        if (message.channelVoice2.status == kMIDICVStatusNoteOn) {
            // Granular engine runs continuously
            // Just confirm MIDI is working
        }
    }

    // MARK: - Waveform Data Access
    const std::vector<float>& getWaveformData() const {
        return mGranularEngine.getAudioBuffer();
    }

    int getWaveformSize() const {
        return mGranularEngine.getBufferSize();
    }

    // MARK: - Member Variables
    AUHostMusicalContextBlock mMusicalContextBlock;

    double mSampleRate = 44100.0;
    double mGain = 0.5;

    bool mBypassed = false;
    AUAudioFrameCount mMaxFramesToRender = 1024;

    GranularEngine mGranularEngine;
};
