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

class GranularEngine {
public:
    GranularEngine(double sampleRate = 44100.0) : mSampleRate(sampleRate), mTime(0.0) {
        // Generate white noise buffer as test audio
        const int bufferSize = static_cast<int>(2.0 * sampleRate); // 2 seconds
        mAudioBuffer.resize(bufferSize);

        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_real_distribution<float> dis(-1.0f, 1.0f);

        for (int i = 0; i < bufferSize; ++i) {
            mAudioBuffer[i] = dis(gen);
        }

        // Reserve grains pool
        mGrains.reserve(128);
    }

    void setGrainSize(float size) {
        mGrainSize = std::clamp(size, 0.001f, 0.5f);
    }

    void setGrainFrequency(float frequency) {
        mGrainFrequency = std::clamp(frequency, 1.0f, 100.0f);
    }

    void setPosition(float pos) {
        mPosition = std::clamp(pos, 0.0f, 1.0f);
    }

    void setPitch(float semitones) {
        // Convert semitones to pitch ratio
        mPitchRatio = std::pow(2.0f, semitones / 12.0f);
    }

    void setRandomness(float randomness) {
        mRandomness = std::clamp(randomness, 0.0f, 1.0f);
    }

    float process() {
        // Grain scheduling based on time
        double grainInterval = 1.0 / mGrainFrequency;

        // Check if it's time to spawn a new grain
        if (mTime - mLastGrainTime >= grainInterval) {
            spawnGrain();
            mLastGrainTime = mTime;
        }

        // Process all grains
        float output = 0.0f;
        auto it = mGrains.begin();
        while (it != mGrains.end()) {
            if (it->isActive()) {
                output += it->process(mSampleRate);
                ++it;
            } else {
                it = mGrains.erase(it);
            }
        }

        mTime += 1.0 / mSampleRate;

        // Soft limit to prevent clipping
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
    double mLastGrainTime = 0.0;

    void spawnGrain() {
        // Calculate start position with randomness
        float randomOffset = (mRandomness > 0.0f) ?
            (static_cast<float>(rand()) / RAND_MAX - 0.5f) * 2.0f * mRandomness : 0.0f;

        float pos = mPosition + randomOffset * 0.1f;
        pos = std::clamp(pos, 0.0f, 1.0f);

        int startPos = static_cast<int>(pos * mAudioBuffer.size());

        // Randomize grain size slightly
        float grainSize = mGrainSize * (1.0f + randomOffset * 0.5f);

        Grain grain;
        grain.init(startPos, grainSize, mPitchRatio, mAudioBuffer);
        mGrains.push_back(grain);
    }

    double mSampleRate;
    double mTime;

    // Parameters
    float mGrainSize = 0.1f;        // seconds
    float mGrainFrequency = 10.0f;  // Hz
    float mPosition = 0.0f;         // 0.0 to 1.0
    float mPitchRatio = 1.0f;       // 1.0 = original pitch
    float mRandomness = 0.0f;       // 0.0 to 1.0

    // Audio buffer (white noise for testing)
    std::vector<float> mAudioBuffer;

    // Active grains
    std::vector<Grain> mGrains;
};
