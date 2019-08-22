/* $Id$ */

/*
 * This file is part of OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 2.
 * OpenTTD is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with OpenTTD. If not, see <http://www.gnu.org/licenses/>.
 */

/** @file cocoa_touch_s.cpp Sound driver for cocoa touch. */

#ifdef WITH_COCOA_TOUCH

#include "stdafx.h"
#include "debug.h"
#include "driver.h"
#include "mixer.h"
#include "cocoa_touch_s.h"

#define Rect        OTTDRect
#define Point       OTTDPoint
#include <AudioUnit/AudioUnit.h>
#undef Rect
#undef Point

#include "safeguards.h"

static FSoundDriver_CocoaTouch iFSoundDriver_CocoaTouch;

static AudioUnit _outputAudioUnit;

/* The CoreAudio callback */
static OSStatus audioCallback(void *inRefCon, AudioUnitRenderActionFlags *inActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList * ioData)
{
	MxMixSamples(ioData->mBuffers[0].mData, ioData->mBuffers[0].mDataByteSize / 4);

	return noErr;
}


const char *SoundDriver_CocoaTouch::Start(const char * const *parm)
{
	AudioComponent comp;
	AudioComponentDescription desc;
	struct AURenderCallbackStruct callback;
	AudioStreamBasicDescription requestedDesc;

	/* Setup a AudioStreamBasicDescription with the requested format */
	requestedDesc.mFormatID = kAudioFormatLinearPCM;
	requestedDesc.mFormatFlags = kLinearPCMFormatFlagIsPacked;
	requestedDesc.mChannelsPerFrame = 2;
	requestedDesc.mSampleRate = GetDriverParamInt(parm, "hz", 44100);

	requestedDesc.mBitsPerChannel = 16;
	requestedDesc.mFormatFlags |= kLinearPCMFormatFlagIsSignedInteger;

	requestedDesc.mFramesPerPacket = 1;
	requestedDesc.mBytesPerFrame = requestedDesc.mBitsPerChannel * requestedDesc.mChannelsPerFrame / 8;
	requestedDesc.mBytesPerPacket = requestedDesc.mBytesPerFrame * requestedDesc.mFramesPerPacket;

	MxInitialize((uint)requestedDesc.mSampleRate);

	/* Locate the default output audio unit */
	desc.componentType = kAudioUnitType_Output;
#if TARGET_OS_MAC && !TARGET_OS_SIMULATOR
	desc.componentSubType = kAudioUnitSubType_DefaultOutput;
#else
	desc.componentSubType = kAudioUnitSubType_RemoteIO;
#endif
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;

	comp = AudioComponentFindNext(NULL, &desc);
	if (comp == NULL) {
		return "cocoa_touch_s: Failed to start CoreAudio: AudioComponentFindNext returned NULL";
	}

	/* Open & initialize the default output audio unit */
	if (AudioComponentInstanceNew(comp, &_outputAudioUnit) != noErr) {
		return "cocoa_touch_s: Failed to start CoreAudio: AudioComponentInstanceNew";
	}

	if (AudioUnitInitialize(_outputAudioUnit) != noErr) {
		return "cocoa_touch_s: Failed to start CoreAudio: AudioUnitInitialize";
	}

	/* Set the input format of the audio unit. */
	if (AudioUnitSetProperty(_outputAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &requestedDesc, sizeof(requestedDesc)) != noErr) {
		return "cocoa_touch_s: Failed to start CoreAudio: AudioUnitSetProperty (kAudioUnitProperty_StreamFormat)";
	}

	/* Set the audio callback */
	callback.inputProc = audioCallback;
	callback.inputProcRefCon = NULL;
	if (AudioUnitSetProperty(_outputAudioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callback, sizeof(callback)) != noErr) {
		return "cocoa_touch_s: Failed to start CoreAudio: AudioUnitSetProperty (kAudioUnitProperty_SetRenderCallback)";
	}

	/* Finally, start processing of the audio unit */
	if (AudioOutputUnitStart(_outputAudioUnit) != noErr) {
		return "cocoa_touch_s: Failed to start CoreAudio: AudioOutputUnitStart";
	}

	/* We're running! */
	return NULL;
}


void SoundDriver_CocoaTouch::Stop()
{
	struct AURenderCallbackStruct callback;

	/* stop processing the audio unit */
	if (AudioOutputUnitStop(_outputAudioUnit) != noErr) {
		DEBUG(driver, 0, "cocoa_touch_s: Core_CloseAudio: AudioOutputUnitStop failed");
		return;
	}

	/* Remove the input callback */
	callback.inputProc = 0;
	callback.inputProcRefCon = 0;
	if (AudioUnitSetProperty(_outputAudioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callback, sizeof(callback)) != noErr) {
		DEBUG(driver, 0, "cocoa_touch_s: Core_CloseAudio: AudioUnitSetProperty (kAudioUnitProperty_SetRenderCallback) failed");
		return;
	}

	if (AudioUnitUninitialize(_outputAudioUnit) != noErr) {
		DEBUG(driver, 0, "cocoa_touch_s: Core_CloseAudio: AudioUnitUninitialize failed");
		return;
	}
}

#endif /* WITH_COCOA_TOUCH */
