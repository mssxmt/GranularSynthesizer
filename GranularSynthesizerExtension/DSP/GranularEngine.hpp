//
//  GranularEngine.hpp
//  GranularSynthesizerExtension
//
//  Granular Synthesis Engine
//

#pragma once

#include "Grain.hpp"
#include <vector>
#include <random>
#include <algorithm>
#include <cmath>

// MARK: - LFO

enum class LFOWaveform {
    sine,
    triangle,
    square,
    sawtooth,
    sampleAndHold
};

class LFO {
public:
    LFO(double sampleRate = 44100.0) : mSampleRate(sampleRate), mPhase(0.0) {}

    void setFrequency(float freq) {
        mFrequency = std::clamp(freq, 0.1f, 20.0f);
    }

    void setWaveform(LFOWaveform waveform) {
        mWaveform = waveform;
    }

    void reset() {
        mPhase = 0.0;
    }

    float process() {
        const double phaseIncrement = mFrequency / mSampleRate;
        mPhase += phaseIncrement;
        if (mPhase >= 1.0) {
            mPhase -= 1.0;
        }

        return computeWaveform(mPhase);
    }

private:
    float computeWaveform(double phase) {
        switch (mWaveform) {
            case LFOWaveform::sine:
                return std::sin(2.0 * M_PI * phase);
            case LFOWaveform::triangle:
                return 2.0f * std::abs(2.0f * phase - 1.0f) - 1.0f;
            case LFOWaveform::square:
                return (phase < 0.5) ? 1.0f : -1.0f;
            case LFOWaveform::sawtooth:
                return 2.0f * phase - 1.0f;
            case LFOWaveform::sampleAndHold:
                if (phase < 0.01) {
                    mLastRandomValue = (static_cast<float>(rand()) / RAND_MAX) * 2.0f - 1.0f;
                }
                return mLastRandomValue;
        }
        return 0.0f;
    }

    double mSampleRate;
    float mFrequency = 1.0f;
    LFOWaveform mWaveform = LFOWaveform::sine;
    double mPhase = 0.0;
    float mLastRandomValue = 0.0f;
};

// MARK: - ADSR Envelope

enum class EnvelopeStage {
    idle,
    attack,
    decay,
    sustain,
    release
};

class ADSREnvelope {
public:
    ADSREnvelope(double sampleRate = 44100.0)
        : mSampleRate(sampleRate)
        , mStage(EnvelopeStage::idle)
        , mLevel(0.0f)
        , mAttackTime(0.01f)
        , mDecayTime(0.1f)
        , mSustainLevel(0.7f)
        , mReleaseTime(0.2f)
        , mCurrentSample(0)
        , mAttackSamples(0)
        , mDecaySamples(0)
        , mReleaseSamples(0)
    {}

    void setAttack(float time) {
        mAttackTime = std::clamp(time, 0.001f, 10.0f);
    }

    void setDecay(float time) {
        mDecayTime = std::clamp(time, 0.001f, 10.0f);
    }

    void setSustain(float level) {
        mSustainLevel = std::clamp(level, 0.0f, 1.0f);
    }

    void setRelease(float time) {
        mReleaseTime = std::clamp(time, 0.001f, 10.0f);
    }

    void trigger() {
        mStage = EnvelopeStage::attack;
        mLevel = 0.0f;
        mCurrentSample = 0;
        mAttackSamples = static_cast<int64_t>(mAttackTime * mSampleRate);
        mDecaySamples = static_cast<int64_t>(mDecayTime * mSampleRate);
        mReleaseSamples = static_cast<int64_t>(mReleaseTime * mSampleRate);
        mReleaseStartLevel = 0.0f;
    }

    void release() {
        if (mStage != EnvelopeStage::idle && mStage != EnvelopeStage::release) {
            mStage = EnvelopeStage::release;
            mCurrentSample = 0;
            mReleaseSamples = static_cast<int64_t>(mReleaseTime * mSampleRate);
            mReleaseStartLevel = mLevel;
        }
    }

    float process() {
        switch (mStage) {
            case EnvelopeStage::idle:
                mLevel = 0.0f;
                break;

            case EnvelopeStage::attack: {
                if (mAttackSamples > 0) {
                    mLevel = static_cast<float>(mCurrentSample) / static_cast<float>(mAttackSamples);
                    mCurrentSample++;
                    if (mCurrentSample >= mAttackSamples) {
                        mLevel = 1.0f;
                        mStage = EnvelopeStage::decay;
                        mCurrentSample = 0;
                    }
                } else {
                    mLevel = 1.0f;
                    mStage = EnvelopeStage::decay;
                }
                break;
            }

            case EnvelopeStage::decay: {
                if (mDecaySamples > 0) {
                    float decayRange = 1.0f - mSustainLevel;
                    mLevel = 1.0f - (static_cast<float>(mCurrentSample) / static_cast<float>(mDecaySamples)) * decayRange;
                    mCurrentSample++;
                    if (mCurrentSample >= mDecaySamples) {
                        mLevel = mSustainLevel;
                        mStage = EnvelopeStage::sustain;
                    }
                } else {
                    mLevel = mSustainLevel;
                    mStage = EnvelopeStage::sustain;
                }
                break;
            }

            case EnvelopeStage::sustain:
                mLevel = mSustainLevel;
                break;

            case EnvelopeStage::release: {
                if (mReleaseSamples > 0) {
                    mLevel = mReleaseStartLevel * (1.0f - static_cast<float>(mCurrentSample) / static_cast<float>(mReleaseSamples));
                    mCurrentSample++;
                    if (mCurrentSample >= mReleaseSamples) {
                        mLevel = 0.0f;
                        mStage = EnvelopeStage::idle;
                    }
                } else {
                    mLevel = 0.0f;
                    mStage = EnvelopeStage::idle;
                }
                break;
            }
        }

        return mLevel;
    }

    bool isActive() const {
        return mStage != EnvelopeStage::idle;
    }

    float getLevel() const {
        return mLevel;
    }

    EnvelopeStage getStage() const {
        return mStage;
    }

    float getAttack() const { return mAttackTime; }
    float getDecay() const { return mDecayTime; }
    float getSustain() const { return mSustainLevel; }
    float getRelease() const { return mReleaseTime; }

private:
    double mSampleRate;
    EnvelopeStage mStage;
    float mLevel;
    float mAttackTime;
    float mDecayTime;
    float mSustainLevel;
    float mReleaseTime;

    // Linear envelope state
    int64_t mCurrentSample;
    int64_t mAttackSamples;
    int64_t mDecaySamples;
    int64_t mReleaseSamples;
    float mReleaseStartLevel;
};

// MARK: - Voice Structure for MIDI

struct Voice {
    int noteNumber;             // MIDI note number (0-127)
    float velocity;              // MIDI velocity (0.0-1.0)
    bool isActive;               // Is voice currently sounding
    bool isInRelease;            // Is voice in release phase
    float basePitchSemitones;    // Pitch shift from MIDI note

    // Per-voice ADSR envelope
    ADSREnvelope envelope;

    // Per-voice grain instances
    std::vector<Grain> grains;

    // Continuous playback (when jitter=0)
    float continuousOutput;      // Direct audio output for continuous playback mode

    Voice(double sampleRate = 44100.0)
        : noteNumber(-1), velocity(0.0f), isActive(false), isInRelease(false), basePitchSemitones(0.0f)
        , envelope(sampleRate), continuousOutput(0.0f) {
        grains.reserve(64);  // Reserve space for grains per voice
    }
};

// MARK: - Grain Region Structure

enum class PlaybackDirection {
    forward,   // FW: forward playback
    backward,  // BF: backward playback
    pingpong,  // Both: forward then backward (ping-pong)
    random     // Random: random direction each grain
};

struct GrainRegion {
    float startPosition = 0.0f;  // 0.0 to 1.0
    float endPosition = 0.25f;   // 0.0 to 1.0
    float gain = 0.01f;          // 0.0 to 0.01 (UI displays 0-100)
    bool active = true;          // enable/disable

    // New parameters
    float jitter = 0.0f;         // Grain/jitter amount (0.0 to 1.0) - adds randomness to playback position
    PlaybackDirection playbackDirection = PlaybackDirection::forward;
    float currentPosition = 0.0f; // Current playback position for UI display (0.0 to 1.0)
    float playbackSpeed = 0.0000227f; // Playback speed: ~1x means 1 region traversal per second (at 44100Hz)

    // Per-region LFO settings (for position/width modulation)
    bool lfoEnabled = false;         // LFO enable/disable
    int lfoWaveform = 0;              // 0=sine, 1=triangle, 2=square, 3=sawtooth, 4=S&H
    float lfoFrequency = 1.0f;        // 0.1Hz - 20Hz
    float lfoDepth = 0.5f;            // 0.0 - 1.0
    int lfoTarget = 0;                // 0=off, 1=position, 2=width

    // Manual setting values (set by XY Pad)
    float manualPosition = 0.0f;     // Manual position from XY Pad
    float manualWidth = 0.25f;        // Manual width from XY Pad

    // Current LFO modulation values (computed by process())
    float lfoPositionMod = 0.0f;  // Current LFO position modulation amount
    float lfoWidthMod = 0.0f;     // Current LFO width modulation amount

    // Ensure valid range
    void normalize() {
        if (startPosition < 0.0f) startPosition = 0.0f;
        if (startPosition > 1.0f) startPosition = 1.0f;
        if (endPosition < 0.0f) endPosition = 0.0f;
        if (endPosition > 1.0f) endPosition = 1.0f;
        if (startPosition > endPosition) {
            std::swap(startPosition, endPosition);
        }
        if (jitter < 0.0f) jitter = 0.0f;
        if (jitter > 1.0f) jitter = 1.0f;
        if (playbackSpeed < 0.00001f) playbackSpeed = 0.00001f;
        if (playbackSpeed > 0.01f) playbackSpeed = 0.01f;

        // LFO parameters
        lfoFrequency = std::clamp(lfoFrequency, 0.1f, 20.0f);
        lfoDepth = std::clamp(lfoDepth, 0.0f, 1.0f);
        lfoTarget = std::clamp(lfoTarget, 0, 2);
        lfoWaveform = std::clamp(lfoWaveform, 0, 4);
        manualPosition = std::clamp(manualPosition, 0.0f, 1.0f);
        manualWidth = std::clamp(manualWidth, 0.02f, 1.0f);
    }
};

// MARK: - LFO Modulation Route

struct LFOModulation {
    bool enabled = false;
    int targetParameter = 0;     // 0=pitch, 1=pan (future), etc.
    float depth = 0.5f;          // modulation depth (0.0 to 1.0)
};

// MARK: - Waveform Data Structure

struct WaveformData {
    std::string name;
    std::vector<float> samples;

    WaveformData() = default;
    WaveformData(const std::string& n, const std::vector<float>& s) : name(n), samples(s) {}
};

class GranularEngine {
public:
    static constexpr int MAX_GRAIN_REGIONS = 8;
    static constexpr int DEFAULT_GRAIN_REGIONS = 1;
    static constexpr int MAX_WAVEFORMS = 16;
    static constexpr int MAX_VOICES = 8;

    GranularEngine(double sampleRate = 44100.0) : mSampleRate(sampleRate), mTime(0.0), mCurrentWaveformIndex(0) {
        // Initialize voices with sample rate
        for (int i = 0; i < MAX_VOICES; ++i) {
            mVoices[i] = Voice(sampleRate);
        }

        // Initialize region LFOs with correct sample rate
        for (int i = 0; i < MAX_GRAIN_REGIONS; ++i) {
            mRegionLFOs[i] = LFO(sampleRate);
        }

        // Generate white noise buffer as default test audio
        addDefaultWaveform();
    }

    void addDefaultWaveform() {
        const int bufferSize = static_cast<int>(2.0 * mSampleRate); // 2 seconds
        std::vector<float> noiseBuffer(bufferSize);

        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_real_distribution<float> dis(-1.0f, 1.0f);

        for (int i = 0; i < bufferSize; ++i) {
            noiseBuffer[i] = dis(gen);
        }

        mWaveforms.push_back(WaveformData("White Noise", noiseBuffer));
        mAudioBuffer = mWaveforms[0].samples;

        // Initialize default grain regions
        mGrainRegions.resize(DEFAULT_GRAIN_REGIONS);
        float regionSize = 1.0f / DEFAULT_GRAIN_REGIONS;
        for (int i = 0; i < DEFAULT_GRAIN_REGIONS; ++i) {
            mGrainRegions[i].startPosition = static_cast<float>(i) * regionSize;
            mGrainRegions[i].endPosition = static_cast<float>(i + 1) * regionSize;
            mGrainRegions[i].gain = 0.01f;
            mGrainRegions[i].active = true;
        }
    }

    // MARK: - Waveform Management

    int getWaveformCount() const {
        return static_cast<int>(mWaveforms.size());
    }

    std::string getWaveformName(int index) const {
        if (index >= 0 && index < static_cast<int>(mWaveforms.size())) {
            return mWaveforms[index].name;
        }
        return "";
    }

    int getCurrentWaveformIndex() const {
        return mCurrentWaveformIndex;
    }

    void setCurrentWaveform(int index) {
        if (index >= 0 && index < static_cast<int>(mWaveforms.size())) {
            mCurrentWaveformIndex = index;
            mAudioBuffer = mWaveforms[index].samples;
        }
    }

    bool loadWaveform(const std::string& name, const float* data, int sampleCount) {
        if (mWaveforms.size() >= MAX_WAVEFORMS) {
            return false; // Max waveforms reached
        }

        std::vector<float> newSamples(data, data + sampleCount);
        mWaveforms.push_back(WaveformData(name, newSamples));

        // Automatically select the newly loaded waveform
        mCurrentWaveformIndex = static_cast<int>(mWaveforms.size()) - 1;
        mAudioBuffer = mWaveforms[mCurrentWaveformIndex].samples;

        return true;
    }

    bool removeWaveform(int index) {
        // Don't allow removing the last waveform (always keep at least one)
        if (mWaveforms.size() <= 1) {
            return false;
        }

        // Don't allow removing if it's the current waveform
        if (index == mCurrentWaveformIndex) {
            return false;
        }

        if (index >= 0 && index < static_cast<int>(mWaveforms.size())) {
            mWaveforms.erase(mWaveforms.begin() + index);

            // Adjust current index if needed
            if (mCurrentWaveformIndex > index) {
                mCurrentWaveformIndex--;
            }

            return true;
        }
        return false;
    }

    // MARK: - LFO Control

    // MARK: - Region LFO Management (Per-region for position/width modulation)

    void setRegionLFOEnabled(int index, bool enabled) {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            mGrainRegions[index].lfoEnabled = enabled;
        }
    }

    void setRegionLFOWaveform(int index, int waveform) {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            mGrainRegions[index].lfoWaveform = std::clamp(waveform, 0, 4);
            if (waveform >= 0 && waveform < 5) {
                mRegionLFOs[index].setWaveform(static_cast<LFOWaveform>(waveform));
            }
        }
    }

    void setRegionLFOFrequency(int index, float frequency) {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            mGrainRegions[index].lfoFrequency = std::clamp(frequency, 0.1f, 20.0f);
            mRegionLFOs[index].setFrequency(mGrainRegions[index].lfoFrequency);
        }
    }

    void setRegionLFODepth(int index, float depth) {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            mGrainRegions[index].lfoDepth = std::clamp(depth, 0.0f, 1.0f);
        }
    }

    void setRegionLFOTarget(int index, int target) {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            mGrainRegions[index].lfoTarget = std::clamp(target, 0, 2);
        }
    }

    bool getRegionLFOEnabled(int index) const {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            return mGrainRegions[index].lfoEnabled;
        }
        return false;
    }

    int getRegionLFOWaveform(int index) const {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            return mGrainRegions[index].lfoWaveform;
        }
        return 0;
    }

    float getRegionLFOFrequency(int index) const {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            return mGrainRegions[index].lfoFrequency;
        }
        return 1.0f;
    }

    float getRegionLFODepth(int index) const {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            return mGrainRegions[index].lfoDepth;
        }
        return 0.5f;
    }

    int getRegionLFOTarget(int index) const {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            return mGrainRegions[index].lfoTarget;
        }
        return 0;
    }

    // MARK: - Manual Position/Width Management (for XY Pad)

    void setRegionManualPosition(int index, float position) {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            mGrainRegions[index].manualPosition = std::clamp(position, 0.0f, 1.0f);
            // Update startPosition immediately if LFO is disabled
            if (!mGrainRegions[index].lfoEnabled || mGrainRegions[index].lfoTarget != 1) {
                float width = mGrainRegions[index].manualWidth;
                mGrainRegions[index].startPosition = std::clamp(mGrainRegions[index].manualPosition, 0.0f, 1.0f - width);
                mGrainRegions[index].endPosition = mGrainRegions[index].startPosition + width;
            }
        }
    }

    void setRegionManualWidth(int index, float width) {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            mGrainRegions[index].manualWidth = std::clamp(width, 0.02f, 1.0f);
            // Update endPosition immediately if LFO is disabled
            if (!mGrainRegions[index].lfoEnabled || mGrainRegions[index].lfoTarget != 2) {
                float pos = mGrainRegions[index].manualPosition;
                float clampedWidth = std::clamp(mGrainRegions[index].manualWidth, 0.02f, 1.0f - pos);
                mGrainRegions[index].startPosition = pos;
                mGrainRegions[index].endPosition = pos + clampedWidth;
            }
        }
    }

    float getRegionManualPosition(int index) const {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            return mGrainRegions[index].manualPosition;
        }
        return 0.0f;
    }

    float getRegionManualWidth(int index) const {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            return mGrainRegions[index].manualWidth;
        }
        return 0.25f;
    }

    // Get current LFO modulation values (for UI animation)
    float getRegionLFOPositionMod(int index) const {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            return mGrainRegions[index].lfoPositionMod;
        }
        return 0.0f;
    }

    float getRegionLFOWidthMod(int index) const {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            return mGrainRegions[index].lfoWidthMod;
        }
        return 0.0f;
    }

    // MARK: - Voice ADSR Envelope Control

    void setEnvelopeAttack(float attack) {
        mVoiceAttack = std::clamp(attack, 0.001f, 10.0f);
    }

    void setEnvelopeDecay(float decay) {
        mVoiceDecay = std::clamp(decay, 0.001f, 10.0f);
    }

    void setEnvelopeSustain(float sustain) {
        mVoiceSustain = std::clamp(sustain, 0.0f, 1.0f);
    }

    void setEnvelopeRelease(float release) {
        mVoiceRelease = std::clamp(release, 0.001f, 10.0f);
    }

    float getEnvelopeAttack() const {
        return mVoiceAttack;
    }

    float getEnvelopeDecay() const {
        return mVoiceDecay;
    }

    float getEnvelopeSustain() const {
        return mVoiceSustain;
    }

    float getEnvelopeRelease() const {
        return mVoiceRelease;
    }

    // MARK: - MIDI Base Pitch Control

    void setBasePitch(float pitch) {
        // Base pitch in MIDI note number (0-127), default 60 = C4
        mBasePitch = std::clamp(pitch, 0.0f, 127.0f);
    }

    float getBasePitch() const {
        return mBasePitch;
    }

    // MARK: - MIDI Note Control

    void noteOn(int noteNumber, float velocity) {
        // Find free voice or reuse oldest
        int voiceIndex = -1;
        for (int i = 0; i < MAX_VOICES; ++i) {
            if (!mVoices[i].isActive) {
                voiceIndex = i;
                break;
            }
        }

        if (voiceIndex == -1) {
            // All voices in use, steal the oldest (not in release)
            for (int i = 0; i < MAX_VOICES; ++i) {
                if (mVoices[i].isActive && !mVoices[i].isInRelease) {
                    voiceIndex = i;
                    break;
                }
            }
        }

        if (voiceIndex != -1) {
            mVoices[voiceIndex].noteNumber = noteNumber;
            mVoices[voiceIndex].velocity = velocity;
            mVoices[voiceIndex].isActive = true;
            mVoices[voiceIndex].isInRelease = false;

            // Calculate pitch from MIDI note (relative to user-defined base pitch)
            // Pitch shift = MIDI note - base pitch (allows proper melodic playing)
            float pitchShift = noteNumber - mBasePitch;
            mVoices[voiceIndex].basePitchSemitones = pitchShift;

            // Trigger voice envelope
            mVoices[voiceIndex].envelope.trigger();
        }
    }

    void noteOff(int noteNumber) {
        for (int i = 0; i < MAX_VOICES; ++i) {
            if (mVoices[i].isActive && mVoices[i].noteNumber == noteNumber && !mVoices[i].isInRelease) {
                // Enter release phase
                mVoices[i].isInRelease = true;
                mVoices[i].envelope.release();
            }
        }
    }

    void allNotesOff() {
        for (int i = 0; i < MAX_VOICES; ++i) {
            if (mVoices[i].isActive && !mVoices[i].isInRelease) {
                mVoices[i].isInRelease = true;
                mVoices[i].envelope.release();
            }
        }
    }

    int getActiveVoiceCount() const {
        int count = 0;
        for (int i = 0; i < MAX_VOICES; ++i) {
            if (mVoices[i].isActive) count++;
        }
        return count;
    }

    // MARK: - Grain Region Management

    int getGrainRegionCount() const {
        return static_cast<int>(mGrainRegions.size());
    }

    const GrainRegion& getGrainRegion(int index) const {
        static GrainRegion s_emptyRegion;
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            return mGrainRegions[index];
        }
        return s_emptyRegion;
    }

    void setGrainRegion(int index, const GrainRegion& region) {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            mGrainRegions[index] = region;
            mGrainRegions[index].normalize();
        }
    }

    void setRegionPlaybackDirection(int index, PlaybackDirection direction) {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            mGrainRegions[index].playbackDirection = direction;
        }
    }

    void setRegionJitter(int index, float jitter) {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            mGrainRegions[index].jitter = std::clamp(jitter, 0.0f, 1.0f);
        }
    }

    void setRegionGain(int index, float gain) {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            mGrainRegions[index].gain = std::clamp(gain, 0.0f, 0.01f);
        }
    }

    void setRegionPlaybackSpeed(int index, float speed) {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            // Range: 0.1x (0.00000227) to 10x (0.000227) speed
            mGrainRegions[index].playbackSpeed = std::clamp(speed, 0.00000227f, 0.000227f);
        }
    }

    float getRegionPlaybackSpeed(int index) const {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            return mGrainRegions[index].playbackSpeed;
        }
        return 0.0000227f;  // Default 1x
    }

    void addGrainRegion() {
        if (mGrainRegions.size() < MAX_GRAIN_REGIONS) {
            GrainRegion newRegion;
            // Set manual position/width (used for LFO modulation calculation)
            newRegion.manualPosition = 0.4f;
            newRegion.manualWidth = 0.2f;
            // Calculate startPosition/endPosition from manual values
            newRegion.startPosition = newRegion.manualPosition;
            newRegion.endPosition = newRegion.manualPosition + newRegion.manualWidth;
            newRegion.gain = 0.01f;
            newRegion.jitter = 0.0f;
            newRegion.playbackDirection = PlaybackDirection::forward;
            newRegion.playbackSpeed = 0.0000227f;  // Default 1x speed
            newRegion.active = true;
            // LFO defaults
            newRegion.lfoEnabled = false;
            newRegion.lfoWaveform = 0;
            newRegion.lfoFrequency = 1.0f;
            newRegion.lfoDepth = 0.5f;
            newRegion.lfoTarget = 0;
            mGrainRegions.push_back(newRegion);
        }
    }

    void removeGrainRegion(int index) {
        if (mGrainRegions.size() > 1 && index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            mGrainRegions.erase(mGrainRegions.begin() + index);
        }
    }

    // Get current playback position for UI animation (0.0 to 1.0)
    float getRegionPlaybackPosition(int index) const {
        if (index >= 0 && index < static_cast<int>(mGrainRegions.size())) {
            return mGrainRegions[index].currentPosition;
        }
        return 0.0f;
    }

    float process() {
        // Process per-region LFOs (for position/width modulation)
        for (int i = 0; i < static_cast<int>(mGrainRegions.size()); ++i) {
            auto& region = mGrainRegions[i];

            if (region.lfoEnabled && region.lfoTarget > 0) {
                // Update LFO waveform if changed
                mRegionLFOs[i].setWaveform(static_cast<LFOWaveform>(region.lfoWaveform));
                mRegionLFOs[i].setFrequency(region.lfoFrequency);

                // Process LFO
                float lfoValue = mRegionLFOs[i].process();
                float modAmount = lfoValue * region.lfoDepth;

                // Calculate base position from manual values
                float leftEdge = region.manualPosition;
                float width = region.manualWidth;

                // Apply LFO modulation
                if (region.lfoTarget == 1) {
                    // Position modulation: ±10%
                    leftEdge += modAmount * 0.1f;
                } else if (region.lfoTarget == 2) {
                    // Width modulation: ±20%
                    width += modAmount * 0.2f * width;
                }

                // Clamp values
                leftEdge = std::clamp(leftEdge, 0.0f, 1.0f - 0.02f);
                width = std::clamp(width, 0.02f, 1.0f - leftEdge);

                // Update region's actual position (used for grain spawning)
                region.startPosition = leftEdge;
                region.endPosition = leftEdge + width;

                // Store modulation values for UI
                region.lfoPositionMod = leftEdge - region.manualPosition;
                region.lfoWidthMod = (width - region.manualWidth) / region.manualWidth;
            } else {
                // LFO disabled: use manual values
                region.startPosition = region.manualPosition;
                region.endPosition = region.manualPosition + region.manualWidth;
                region.lfoPositionMod = 0.0f;
                region.lfoWidthMod = 0.0f;
            }
        }

        // Process each voice
        float output = 0.0f;
        int activeCount = 0;

        for (int i = 0; i < MAX_VOICES; ++i) {
            if (mVoices[i].isActive) {
                // Reset continuous output for this sample
                mVoices[i].continuousOutput = 0.0f;

                // Update envelope parameters (in case they changed)
                mVoices[i].envelope.setAttack(mVoiceAttack);
                mVoices[i].envelope.setDecay(mVoiceDecay);
                mVoices[i].envelope.setSustain(mVoiceSustain);
                mVoices[i].envelope.setRelease(mVoiceRelease);

                // Process voice envelope to get master volume level
                float masterEnvLevel = mVoices[i].envelope.process();

                // Check if release phase has ended
                if (mVoices[i].isInRelease && !mVoices[i].envelope.isActive()) {
                    // Release finished, stop the voice
                    mVoices[i].isActive = false;
                    mVoices[i].isInRelease = false;
                    mVoices[i].grains.clear();
                    mVoices[i].continuousOutput = 0.0f;
                    continue;
                }

                activeCount++;

                // Process each active region for this voice
                // Continue spawning grains even during release phase
                for (auto& region : mGrainRegions) {
                    if (region.active) {
                        // Update region playback position for UI display with voice pitch
                        updateRegionPlaybackPosition(region, mVoices[i]);

                        // Spawn grain for this region at current playback position
                        spawnGrainForPlayback(mVoices[i], region);
                    }
                }

                // Process this voice's grains
                float voiceOutput = 0.0f;
                auto it = mVoices[i].grains.begin();
                while (it != mVoices[i].grains.end()) {
                    if (it->isActive()) {
                        voiceOutput += it->process(mSampleRate);
                        ++it;
                    } else {
                        it = mVoices[i].grains.erase(it);
                    }
                }

                // Add continuous output (from jitter=0 regions) with envelope applied
                voiceOutput += mVoices[i].continuousOutput * masterEnvLevel;

                // Clear continuous output after applying envelope (it's regenerated each sample)
                mVoices[i].continuousOutput = 0.0f;

                // Apply velocity and MASTER envelope (amp) to voice output
                // ADSR controls overall voice level, affecting all grains in real-time
                output += voiceOutput * mVoices[i].velocity * masterEnvLevel;
            }
        }

        mTime += 1.0 / mSampleRate;

        // Normalize by active voice count and soft limit
        if (activeCount > 0) {
            output /= activeCount;
        }

        return std::tanh(output);
    }

    // MARK: - Waveform Data Access
    const std::vector<float>& getAudioBuffer() const {
        return mAudioBuffer;
    }

    int getBufferSize() const {
        return static_cast<int>(mAudioBuffer.size());
    }

private:
    // Track region playback state
    struct RegionPlaybackState {
        float position = 0.0f;      // Current position (0.0 to 1.0)
        bool goingForward = true;   // For ping-pong playback
        int samplesUntilNextGrain = 0;  // Samples until next grain spawn
    };
    std::array<RegionPlaybackState, MAX_GRAIN_REGIONS> mRegionPlaybackStates = {};

    // Per-region LFOs for position/width modulation
    std::array<LFO, MAX_GRAIN_REGIONS> mRegionLFOs;

    void updateRegionPlaybackPosition(GrainRegion& region, const Voice& voice) {
        int regionIndex = 0;
        for (size_t i = 0; i < mGrainRegions.size(); ++i) {
            if (&mGrainRegions[i] == &region) {
                regionIndex = static_cast<int>(i);
                break;
            }
        }

        auto& state = mRegionPlaybackStates[regionIndex];

        // Note: region.startPosition/endPosition are already updated by process() with LFO modulation
        float range = region.endPosition - region.startPosition;

        // Calculate voice pitch ratio for pitch shifting
        float voicePitchRatio = std::pow(2.0f, voice.basePitchSemitones / 12.0f);

        // Update position based on direction with region's playback speed and voice pitch
        float speed = region.playbackSpeed * voicePitchRatio;

        bool looped = false;  // Track if we looped (for random mode)

        if (region.playbackDirection == PlaybackDirection::backward) {
            // BF: Backward playback
            state.position -= speed;
            if (state.position <= 0.0f) {
                state.position = 1.0f;
                looped = true;
            }
        } else if (region.playbackDirection == PlaybackDirection::pingpong) {
            // Both: Ping-pong playback (forward to end, then reverse)
            if (state.goingForward) {
                state.position += speed;
                if (state.position >= 1.0f) {
                    state.position = 1.0f;
                    state.goingForward = false;
                }
            } else {
                state.position -= speed;
                if (state.position <= 0.0f) {
                    state.position = 0.0f;
                    state.goingForward = true;
                }
            }
        } else if (region.playbackDirection == PlaybackDirection::random) {
            // Rnd: Forward playback with random position on loop
            state.position += speed;
            if (state.position >= 1.0f) {
                state.position = static_cast<float>(rand()) / RAND_MAX;  // Random new position
                looped = true;
            }
        } else {
            // FW: Forward playback (default)
            state.position += speed;
            if (state.position >= 1.0f) {
                state.position = 0.0f;
                looped = true;
            }
        }

        // Update region's currentPosition for UI (clamped to region bounds)
        // Add visual jitter for UI display when jitter > 0
        float visualPosition = region.startPosition + state.position * range;
        if (region.jitter > 0.0f) {
            // Apply visual jitter (same reduced sensitivity as audio jitter)
            float jitterAmount = std::sqrt(region.jitter) * range * 0.15f;
            float jitterOffset = (static_cast<float>(rand()) / RAND_MAX - 0.5f) * 2.0f * jitterAmount;
            visualPosition += jitterOffset;
            visualPosition = std::clamp(visualPosition, region.startPosition, region.endPosition);
        }
        region.currentPosition = visualPosition;
    }

    // Helper: Get interpolated audio sample from buffer at position (0.0-1.0)
    float getInterpolatedSample(float position) {
        if (mAudioBuffer.empty()) {
            // Return silence if buffer is empty
            return 0.0f;
        }

        float posFloat = position * (mAudioBuffer.size() - 1);
        int posInt = static_cast<int>(posFloat);
        float frac = posFloat - posInt;

        // Clamp to valid range
        posInt = std::clamp(posInt, 0, static_cast<int>(mAudioBuffer.size()) - 2);

        // Linear interpolation
        float sample1 = mAudioBuffer[posInt];
        float sample2 = mAudioBuffer[posInt + 1];
        return sample1 + frac * (sample2 - sample1);
    }

    void spawnGrainForPlayback(Voice& voice, GrainRegion& region) {
        int regionIndex = 0;
        for (size_t i = 0; i < mGrainRegions.size(); ++i) {
            if (&mGrainRegions[i] == &region) {
                regionIndex = static_cast<int>(i);
                break;
            }
        }

        auto& state = mRegionPlaybackStates[regionIndex];

        // Count active regions to adjust spawn rate
        int activeRegionCount = 0;
        for (const auto& r : mGrainRegions) {
            if (r.active) activeRegionCount++;
        }

        // Normalize gain by active region count to prevent overload
        float normalizedGain = region.gain / std::sqrt(static_cast<float>(activeRegionCount));

        // Apply voice pitch (from MIDI note, relative to base pitch)
        float voicePitchRatio = std::pow(2.0f, voice.basePitchSemitones / 12.0f);

        if (region.jitter == 0.0f) {
            // CONTINUOUS PLAYBACK MODE (jitter=0)
            // Read directly from audio buffer at current playback position
            // region.startPosition/endPosition already include LFO modulation (updated in process())
            float range = region.endPosition - region.startPosition;
            float pos = region.startPosition + state.position * range;

            // Get interpolated sample from audio buffer
            float sample = getInterpolatedSample(pos);

            // Apply gain and envelope for continuous mode
            voice.continuousOutput += sample * normalizedGain;
        } else {
            // GRANULAR MODE (jitter>0)
            // Spawn discrete grains with position jitter

            // Adjust spawn rate based on active region count to prevent overload
            // More regions = slower spawn rate per region
            int baseSpawnRate = 1000;  // Base: every 1000 samples
            int adjustedSpawnRate = baseSpawnRate * activeRegionCount;  // Scale with region count
            adjustedSpawnRate = std::clamp(adjustedSpawnRate, 1000, 8000);  // Limit range

            state.samplesUntilNextGrain--;
            if (state.samplesUntilNextGrain > 0) {
                return;
            }
            state.samplesUntilNextGrain = adjustedSpawnRate;

            // region.startPosition/endPosition already include LFO modulation (updated in process())
            float range = region.endPosition - region.startPosition;
            float pos = region.startPosition + state.position * range;

            // Apply jitter (reduced sensitivity using sqrt)
            float jitterAmount = std::sqrt(region.jitter) * range * 0.15f;
            float jitterOffset = (static_cast<float>(rand()) / RAND_MAX - 0.5f) * 2.0f * jitterAmount;
            pos += jitterOffset;
            pos = std::clamp(pos, region.startPosition, region.endPosition);

            int startPos = static_cast<int>(pos * mAudioBuffer.size());

            // Grain parameters
            float grainSize = 0.05f;  // Fixed 50ms grains

            Grain grain;
            grain.init(startPos, grainSize, voicePitchRatio, mAudioBuffer);
            grain.setGain(normalizedGain);
            grain.setVolumeScale(1.0f);  // Volume controlled by voice-level ADSR

            voice.grains.push_back(grain);
        }
    }

    double mSampleRate;
    double mTime;


    // Voice ADSR parameters (shared by all voices) - Master AMP envelope
    float mVoiceAttack = 0.01f;
    float mVoiceDecay = 0.1f;
    float mVoiceSustain = 0.7f;
    float mVoiceRelease = 0.2f;

    // MIDI base pitch (MIDI note number, default 60 = C4)
    float mBasePitch = 60.0f;

    // Waveforms
    std::vector<WaveformData> mWaveforms;
    int mCurrentWaveformIndex;

    // Grain regions
    std::vector<GrainRegion> mGrainRegions;

    // Audio buffer (white noise for testing)
    std::vector<float> mAudioBuffer;

    // Polyphonic voices for MIDI
    Voice mVoices[MAX_VOICES];
};
