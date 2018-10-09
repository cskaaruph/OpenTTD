/* $Id$ */

/*
 * This file is part of OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 2.
 * OpenTTD is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with OpenTTD. If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * @file cocoa_touch_m.cpp
 * @brief MIDI music player for iOS using CoreAudio.
 */


#ifdef WITH_COCOA_TOUCH

#include "stdafx.h"
#include "cocoa_touch_m.h"
#include "midifile.hpp"
#include "debug.h"
#include <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h>

#include "safeguards.h"

static FMusicDriver_CocoaTouch iFMusicDriver_CocoaTouch;


static MusicPlayer    _player = NULL;
static MusicSequence  _sequence = NULL;
static MusicTimeStamp _seq_length = 0;
static bool           _playing = false;
static byte           _volume = 127;


/** Set the volume of the current sequence. */
static void DoSetVolume()
{
	if (_sequence == NULL) return;

	AUGraph graph;
	MusicSequenceGetAUGraph(_sequence, &graph);

	AudioUnit output_unit = NULL;

	/* Get output audio unit */
	UInt32 node_count = 0;
	AUGraphGetNodeCount(graph, &node_count);
	for (UInt32 i = 0; i < node_count; i++) {
		AUNode node;
		AUGraphGetIndNode(graph, i, &node);

		AudioUnit unit;
		OSType comp_type = 0;

		AudioComponentDescription desc;
		AUGraphNodeInfo(graph, node, &desc, &unit);
		comp_type = desc.componentType;

		if (comp_type == kAudioUnitType_Output) {
			output_unit = unit;
			break;
		}
	}
	if (output_unit == NULL) {
		DEBUG(driver, 1, "cocoa_touch_m: Failed to get output node to set volume");
		return;
	}

	Float32 vol = _volume / 127.0f;  // 0 - +127 -> 0.0 - 1.0
	AudioUnitSetParameter(output_unit, kHALOutputParam_Volume, kAudioUnitScope_Global, 0, vol, 0);
}


/**
 * Initializes the MIDI player
 */
const char *MusicDriver_CocoaTouch::Start(const char * const *parm)
{
	if (NewMusicPlayer(&_player) != noErr) return "failed to create music player";

	return NULL;
}


/**
 * Checks wether the player is active.
 */
bool MusicDriver_CocoaTouch::IsSongPlaying()
{
	if (!_playing) return false;

	MusicTimeStamp time = 0;
	MusicPlayerGetTime(_player, &time);
	return time < _seq_length;
}


/**
 * Stops the MIDI player.
 */
void MusicDriver_CocoaTouch::Stop()
{
	if (_player != NULL) DisposeMusicPlayer(_player);
	_player = NULL;
	if (_sequence != NULL) DisposeMusicSequence(_sequence);
	_sequence = NULL;
}


/**
 * Starts playing a new song.
 *
 * @param song Description of music to load and play
 */
void MusicDriver_CocoaTouch::PlaySong(const MusicSongInfo &song)
{
	std::string filename = MidiFile::GetSMFFile(song);
	DEBUG(driver, 2, "cocoa_touch_m: trying to play '%s'", filename.c_str());

	this->StopSong();
	if (_sequence != NULL) {
		DisposeMusicSequence(_sequence);
		_sequence = NULL;
	}
	
	if (filename.empty()) return;

	if (NewMusicSequence(&_sequence) != noErr) {
		DEBUG(driver, 0, "cocoa_touch_m: Failed to create music sequence");
		return;
	}

	const char *os_file = OTTD2FS(filename.c_str());
	CFURLRef url = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, (const UInt8*)os_file, strlen(os_file), false);
	if (MusicSequenceFileLoad(_sequence, url, kMusicSequenceFile_AnyType, 0) != noErr) {
		DEBUG(driver, 0, "cocoa_touch_m: Failed to load MIDI file");
		CFRelease(url);
		return;
	}
	CFRelease(url);

	/* Construct audio graph */
	AUGraph graph = NULL;

	MusicSequenceGetAUGraph(_sequence, &graph);
	AUGraphOpen(graph);
	if (AUGraphInitialize(graph) != noErr) {
		DEBUG(driver, 0, "cocoa_touch_m: Failed to initialize AU graph");
		return;
	}

	/* Figure out sequence length */
	UInt32 num_tracks;
	MusicSequenceGetTrackCount(_sequence, &num_tracks);
	_seq_length = 0;
	for (UInt32 i = 0; i < num_tracks; i++) {
		MusicTrack     track = NULL;
		MusicTimeStamp track_length = 0;
		UInt32         prop_size = sizeof(MusicTimeStamp);
		MusicSequenceGetIndTrack(_sequence, i, &track);
		MusicTrackGetProperty(track, kSequenceTrackProperty_TrackLength, &track_length, &prop_size);
		if (track_length > _seq_length) _seq_length = track_length;
	}
	/* Add 8 beats for reverb/long note release */
	_seq_length += 8;

	DoSetVolume();
	MusicPlayerSetSequence(_player, _sequence);
	MusicPlayerPreroll(_player);
	if (MusicPlayerStart(_player) != noErr) return;
	_playing = true;

	DEBUG(driver, 3, "cocoa_touch_m: playing '%s'", filename.c_str());
}


/**
 * Stops playing the current song, if the player is active.
 */
void MusicDriver_CocoaTouch::StopSong()
{
	MusicPlayerStop(_player);
	MusicPlayerSetSequence(_player, NULL);
	_playing = false;
}


/**
 * Changes the playing volume of the MIDI player.
 *
 * @param vol The desired volume, range of the value is @c 0-127
 */
void MusicDriver_CocoaTouch::SetVolume(byte vol)
{
	_volume = vol;
	DoSetVolume();
}

#endif /* WITH_COCOA_TOUCH */
