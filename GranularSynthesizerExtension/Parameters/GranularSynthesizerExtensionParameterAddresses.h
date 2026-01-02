//
//  GranularSynthesizerExtensionParameterAddresses.h
//  GranularSynthesizerExtension
//
//  Created by MasashiXimoto on 2026/01/02.
//

#pragma once

#include <AudioToolbox/AUParameters.h>

#ifdef __cplusplus
namespace GranularSynthesizerExtensionParameterAddress {
#endif

typedef NS_ENUM(AUParameterAddress, GranularSynthesizerExtensionParameterAddress) {
    gain = 0,
    grainSize,
    grainFrequency,
    position,
    pitch,
    randomness
};

#ifdef __cplusplus
}
#endif
