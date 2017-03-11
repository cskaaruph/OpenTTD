/* $Id$ */

/*
 * This file is part of OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 2.
 * OpenTTD is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with OpenTTD. If not, see <http://www.gnu.org/licenses/>.
 */

/** @file cocoa_touch_v.mm Code related to the cocoa touch video driver(s). */

#import <UIKit/UIKit.h>
#include "stdafx.h"
#import "cocoa_touch_v.h"

#include "openttd.h"
#include "debug.h"
#include "factory.hpp"
#include "gfx_func.h"
#include "fontcache.h"

static FVideoDriver_CocoaTouch iFVideoDriver_CocoaTouch;
VideoDriver_CocoaTouch *_cocoa_touch_driver = NULL;

extern "C" {
	CALayer *_cocoa_touch_layer = NULL;
	extern char ***_NSGetArgv(void);
	extern int *_NSGetArgc(void);
	extern jmp_buf _out_of_loop;
}

const char *VideoDriver_CocoaTouch::Start(const char * const *parm)
{
	// TODO: detect start in landscape
	UIScreen *mainScreen = [UIScreen mainScreen];
	CGFloat scale = mainScreen.nativeScale;
	_resolutions[0].width = mainScreen.bounds.size.width * scale;
	_resolutions[0].height = mainScreen.bounds.size.height * scale;
	_num_resolutions = 1;
	this->ChangeResolution(_resolutions[0].width, _resolutions[0].height);
	_cocoa_touch_driver = this;
	return NULL;
}

void VideoDriver_CocoaTouch::Stop()
{
	CGContextRelease(this->context);
	free(this->pixel_buffer);
	_cocoa_touch_driver = NULL;
}

void VideoDriver_CocoaTouch::ExitMainLoop()
{
	CFRunLoopStop([[NSRunLoop mainRunLoop] getCFRunLoop]);
	longjmp(main_loop_jmp, 1);
}

void VideoDriver_CocoaTouch::MainLoop()
{
	if (setjmp(main_loop_jmp) == 0) {
		UIApplicationMain(*_NSGetArgc(), *_NSGetArgv(), nil, @"AppDelegate");
	}
}

void VideoDriver_CocoaTouch::MakeDirty(int left, int top, int width, int height)
{
	
}

bool VideoDriver_CocoaTouch::ChangeResolution(int w, int h)
{
	_screen.width = w;
	_screen.height = h;
	_screen.pitch = _screen.width;
	size_t buffer_size = _screen.pitch * _screen.height * 4;
	if (pixel_buffer) {
		free(pixel_buffer);
	}
	pixel_buffer = malloc(buffer_size);
	
	Blitter *blitter = BlitterFactory::GetCurrentBlitter();
	assert(blitter->GetScreenDepth() == 32);
	
	int bitsPerComponent = 8;
	int bitsPerPixel = 32;
	int bytesPerRow = _screen.width * 4;
	CGBitmapInfo options = kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst;
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	if (this->context) {
		CGContextRelease(this->context);
	}
	this->context = CGBitmapContextCreate(pixel_buffer, _screen.width, _screen.height, bitsPerComponent, bytesPerRow, colorSpace, options);
	CGColorSpaceRelease(colorSpace);
	_screen.dst_ptr = pixel_buffer;
	if (_cocoa_touch_layer == NULL) {
		_cocoa_touch_layer = [CALayer layer];
	}
	_fullscreen = true;
	
	BlitterFactory::GetCurrentBlitter()->PostResize();
	GameSizeChanged();
	
	return true;
}

bool VideoDriver_CocoaTouch::ToggleFullscreen(bool fullsreen)
{
	return false;
}

bool VideoDriver_CocoaTouch::AfterBlitterChange()
{
	return this->ChangeResolution(_screen.width, _screen.height);
}

void VideoDriver_CocoaTouch::EditBoxLostFocus()
{
	
}

void VideoDriver_CocoaTouch::Draw()
{
	CGImageRef screenImage = CGBitmapContextCreateImage(this->context);
	_cocoa_touch_layer.contents = (__bridge id)screenImage;
	CGImageRelease(screenImage);
}

void VideoDriver_CocoaTouch::UpdatePalette(uint first_color, uint num_colors)
{
	
}
