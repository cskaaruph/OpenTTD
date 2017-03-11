/* $Id$ */

/*
 * This file is part of OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 2.
 * OpenTTD is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with OpenTTD. If not, see <http://www.gnu.org/licenses/>.
 */

/** @file cocoa_touch_s.h Base for Cocoa Touch sound handling. */

#ifndef SOUND_COCOA_TOUCH_H
#define SOUND_COCOA_TOUCH_H

#include "sound_driver.hpp"

class SoundDriver_CocoaTouch : public SoundDriver {
public:
	/* virtual */ const char *Start(const char * const *param);

	/* virtual */ void Stop();
	/* virtual */ const char *GetName() const { return "cocoa_touch"; }
};

class FSoundDriver_CocoaTouch : public DriverFactoryBase {
public:
	FSoundDriver_CocoaTouch() : DriverFactoryBase(Driver::DT_SOUND, 10, "cocoa_touch", "Cocoa Touch Sound Driver") {}
	/* virtual */ Driver *CreateInstance() const { return new SoundDriver_CocoaTouch(); }
};

#endif /* SOUND_COCOA_TOUCH_H */
