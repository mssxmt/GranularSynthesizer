//
//  Grain.hpp
//  GranularSynthesizerExtension
//
//  Granular Synthesis Grain Structure
//

#pragma once

#include <vector>
#include <cmath>
#include <algorithm>

class Grain {
public:
    Grain() : active(false), position(0.0), age(0.0), gain(1.0f), volumeScale(1.0f) {}

    void init(int startPos, float dur, float pitchRatio, const std::vector<float>& audioBuffer) {
        startPosition = startPos;
        duration = dur;
        playbackSpeed = pitchRatio;
        buffer = audioBuffer;
        position = 0.0;
        age = 0.0;
        active = true;
        volumeScale = 1.0f;  // Reset volume scale

        // Apply envelope (Hanning window)
        size_t numSamples = static_cast<size_t>(dur * 44100.0);
        envelope.resize(numSamples);
        for (size_t i = 0; i < numSamples; ++i) {
            float phase = static_cast<float>(i) / static_cast<float>(numSamples - 1);
            envelope[i] = 0.5f * (1.0f - std::cos(phase * 2.0f * M_PI));
        }
    }

    void setGain(float g) {
        gain = std::clamp(g, 0.0f, 1.0f);
    }

    void setVolumeScale(float scale) {
        volumeScale = std::clamp(scale, 0.0f, 1.0f);
    }

    float process(double sampleRate) {
        if (!active || age >= duration) {
            active = false;
            return 0.0f;
        }

        // Calculate read position with pitch
        int readPos = startPosition + static_cast<int>(position * playbackSpeed);

        // Boundary check
        if (readPos >= static_cast<int>(buffer.size()) - 1) {
            active = false;
            return 0.0f;
        }

        // Linear interpolation
        float frac = static_cast<float>(position * playbackSpeed) - std::floor(position * playbackSpeed);
        float sample = buffer[readPos] * (1.0f - frac) + buffer[readPos + 1] * frac;

        // Apply envelope
        size_t envIndex = static_cast<size_t>(age / duration * (envelope.size() - 1));
        float envValue = (envIndex < envelope.size()) ? envelope[envIndex] : 0.0f;

        // Advance
        position += 1.0;
        age += 1.0 / sampleRate;

        return sample * envValue * gain * volumeScale;
    }

    bool isActive() const { return active; }

private:
    bool active;
    int startPosition;
    float duration;
    float playbackSpeed;
    double position;
    double age;
    float gain;
    float volumeScale;  // Additional volume scaling from voice envelope at creation time

    std::vector<float> buffer;
    std::vector<float> envelope;
};
