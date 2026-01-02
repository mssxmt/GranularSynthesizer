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
    Grain() : active(false), position(0.0), age(0.0) {}

    void init(int startPos, float dur, float pitchRatio, const std::vector<float>& audioBuffer) {
        startPosition = startPos;
        duration = dur;
        playbackSpeed = pitchRatio;
        buffer = audioBuffer;
        position = 0.0;
        age = 0.0;
        active = true;

        // Apply envelope (Hanning window)
        size_t numSamples = static_cast<size_t>(dur * 44100.0);
        envelope.resize(numSamples);
        for (size_t i = 0; i < numSamples; ++i) {
            float phase = static_cast<float>(i) / static_cast<float>(numSamples - 1);
            envelope[i] = 0.5f * (1.0f - std::cos(phase * 2.0f * M_PI));
        }
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

        return sample * envValue;
    }

    bool isActive() const { return active; }

private:
    bool active;
    int startPosition;
    float duration;
    float playbackSpeed;
    double position;
    double age;

    std::vector<float> buffer;
    std::vector<float> envelope;
};
