/* $Id$ */

/*
 * This file is part of OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 2.
 * OpenTTD is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with OpenTTD. If not, see <http://www.gnu.org/licenses/>.
 */

/** @file cocoa_m.h Base of music playback via CoreAudio. */

#ifndef MUSIC_IOS_H
#define MUSIC_IOS_H

#include "music_driver.hpp"

class MusicDriver_CocoaTouch : public MusicDriver {
public:
	/* virtual */ const char *Start(const char * const *param);

	/* virtual */ void Stop();

	/* virtual */ void PlaySong(const MusicSongInfo &song);

	/* virtual */ void StopSong();

	/* virtual */ bool IsSongPlaying();

	/* virtual */ void SetVolume(byte vol);
	/* virtual */ const char *GetName() const { return "cocoa_touch"; }
};

class FMusicDriver_CocoaTouch : public DriverFactoryBase {
public:
	FMusicDriver_CocoaTouch() : DriverFactoryBase(Driver::DT_MUSIC, 10, "cocoa_touch", "Cocoa Touch MIDI Driver") {}
	/* virtual */ Driver *CreateInstance() const { return new MusicDriver_CocoaTouch(); }
};

#endif /* MUSIC_IOS_H */
