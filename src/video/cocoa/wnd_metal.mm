//
//  wnd_metal.mm
//  OpenTTD_Mac
//
//  Created by Christian Skaarup Enevoldsen on 22/08/2019.
//  Copyright © 2019 OpenTTD. All rights reserved.
//

/* $Id$ */

/*
 * This file is part of OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 2.
 * OpenTTD is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with OpenTTD. If not, see <http://www.gnu.org/licenses/>.
 */

/******************************************************************************
 *                             Cocoa video driver                             *
 * Known things left to do:                                                   *
 *  List available resolutions.                                               *
 ******************************************************************************/

#ifdef WITH_COCOA
#ifdef ENABLE_COCOA_METAL

#include "../../stdafx.h"
#include "../../os/macosx/macos.h"

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4

#define Rect  OTTDRect
#define Point OTTDPoint
#import <Cocoa/Cocoa.h>
#undef Rect
#undef Point

#include "../../debug.h"
#include "../../rev.h"
#include "../../core/geometry_type.hpp"
#include "cocoa_v.h"
#include "../../core/math_func.hpp"
#include "../../gfx_func.h"
#include "../../framerate_type.h"

#include "factory.hpp"

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

/* On some old versions of MAC OS this may not be defined.
 * Those versions generally only produce code for PPC. So it should be safe to
 * set this to 0. */
#ifndef kCGBitmapByteOrder32Host
#define kCGBitmapByteOrder32Host 0
#endif

static id<MTLCommandQueue> commandQueue = nil;
static id<MTLRenderPipelineState> pipelineState = nil;
static id<MTLBuffer> vertexBuffer = nil;
static MTLTextureDescriptor *textureDescriptor = nil;

/**
 * Important notice regarding all modifications!!!!!!!
 * There are certain limitations because the file is objective C++.
 * gdb has limitations.
 * C++ and objective C code can't be joined in all cases (classes stuff).
 * Read http://developer.apple.com/releasenotes/Cocoa/Objective-C++.html for more information.
 */

class WindowMetalSubdriver;

/* Subclass of OTTD_CocoaView to fix Metal rendering */
@interface OTTD_MetalView : OTTD_CocoaView
@property (strong) CAMetalLayer *cocoa_touch_layer;
@property (nonatomic, strong) NSOperationQueue *queue;


- (void)setDriver:(WindowMetalSubdriver*)drv;
@end

class WindowMetalSubdriver : public CocoaSubdriver {
private:
	/**
	 * This function copies 8bpp pixels from the screen buffer in 32bpp windowed mode.
	 *
	 * @param left The x coord for the left edge of the box to blit.
	 * @param top The y coord for the top edge of the box to blit.
	 * @param right The x coord for the right edge of the box to blit.
	 * @param bottom The y coord for the bottom edge of the box to blit.
	 */
	void BlitIndexedToView32(int left, int top, int right, int bottom);
	
	virtual void GetDeviceInfo();
	virtual bool SetVideoMode(int width, int height, int bpp);
	
public:
	WindowMetalSubdriver();
	virtual ~WindowMetalSubdriver();
	
	virtual void Draw(bool force_update);
	virtual void MakeDirty(int left, int top, int width, int height);
	virtual void UpdatePalette(uint first_color, uint num_colors);
	
	virtual uint ListModes(OTTD_Point *modes, uint max_modes);
	
	virtual bool ChangeResolution(int w, int h, int bpp);
	
	virtual bool IsFullscreen() { return false; }
	virtual bool ToggleFullscreen(); /* Full screen mode on OSX 10.7 */
	
	virtual int GetWidth() { return window_width; }
	virtual int GetHeight() { return window_height; }
//	virtual void *GetPixelBuffer() { return buffer_depth == 8 ? pixel_buffer : window_buffer; }
	virtual void *GetPixelBuffer() { return pixel_buffer; }
	/* Convert local coordinate to window server (CoreGraphics) coordinate */
	virtual CGPoint PrivateLocalToCG(NSPoint *p);
	
	virtual NSPoint GetMouseLocation(NSEvent *event);
	virtual bool MouseIsInsideView(NSPoint *pt);
	
	virtual bool IsActive() { return active; }
	
	
	void SetPortAlphaOpaque();
	bool WindowResized();
	void SetupMetal();
	void ChangeMetalResolution(int w, int h);
	
	OTTD_CocoaWindowDelegate *cocoaWindowDelegate;
};


@implementation OTTD_MetalView

- (NSOperationQueue *)queue {
	if (_queue == nil) {
		_queue = [NSOperationQueue new];
		_queue.maxConcurrentOperationCount = 1;
		_queue.name = @"OTTD_Metal";
	}
	return _queue;
}

- (void)setFrame:(NSRect)frame {
	[super setFrame:frame];
	self.cocoa_touch_layer.frame = self.bounds;
	self.cocoa_touch_layer.drawableSize = CGSizeMake(_screen.width, _screen.height);
}

- (void)setDriver:(WindowMetalSubdriver*)drv
{
	driver = drv;
}

- (void)draw {
	if (self.isPaused) {
		return;
	}
	
	CAMetalLayer *metalLayer = self.cocoa_touch_layer;
	if (CGSizeEqualToSize(metalLayer.drawableSize, CGSizeZero)) {
		NSLog(@"The drawable's size is empty");
		return;
	}
	
	id<CAMetalDrawable> drawable = [metalLayer nextDrawable];
	if (!drawable) {
		NSLog(@"The drawable cannot be nil");
		return;
	}
	
	int pitch = _screen.pitch;
	
	if (pitch % 64) {
		pitch += (64 - (pitch % 64));
	}
	
	size_t buffer_size = _screen.pitch * _screen.height * 4;
	if (buffer_size % 4096) {
		buffer_size += (4096 - (buffer_size % 4096));
	}
	
	void *pixel_buffer = driver->pixel_buffer;
	id<MTLBuffer> screenBuffer = [metalLayer.device newBufferWithBytes:pixel_buffer length:buffer_size options: MTLResourceStorageModeManaged];
	
	[self.queue addOperationWithBlock:^{
		id <MTLTexture> screenTexture = [screenBuffer newTextureWithDescriptor:textureDescriptor offset:0 bytesPerRow:(pitch * 4)];
		
		MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor new];
		renderPassDescriptor.colorAttachments[0].texture = drawable.texture;
		renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
		renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
		
		id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
		
		id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
		[commandEncoder setRenderPipelineState:pipelineState];
		[commandEncoder setVertexBuffer:vertexBuffer offset:0 atIndex:0];
		[commandEncoder setFragmentTexture:screenTexture atIndex:0];
		[commandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4 instanceCount:1];
		[commandEncoder endEncoding];
		
		[commandBuffer presentDrawable:drawable];
		[commandBuffer commit];
		[commandBuffer waitUntilCompleted];
	}];
}
@end


void WindowMetalSubdriver::GetDeviceInfo()
{
	/* Use the new API when compiling for OSX 10.6 or later */
	CGDisplayModeRef cur_mode = CGDisplayCopyDisplayMode(kCGDirectMainDisplay);
	if (cur_mode == NULL) { return; }
	
	this->device_width = (int)CGDisplayModeGetWidth(cur_mode);
	this->device_height = (int)CGDisplayModeGetHeight(cur_mode);
	
	CGDisplayModeRelease(cur_mode);
}

/** Switch to full screen mode on OSX 10.7
 * @return Whether we switched to full screen
 */
bool WindowMetalSubdriver::ToggleFullscreen()
{
	if ([ this->window respondsToSelector:@selector(toggleFullScreen:) ]) {
		[ this->window performSelector:@selector(toggleFullScreen:) withObject:this->window ];
		return true;
	}
	
	return false;
}

bool WindowMetalSubdriver::SetVideoMode(int width, int height, int bpp)
{
	this->setup = true;
	this->GetDeviceInfo();
	
	if (width > this->device_width) width = this->device_width;
	if (height > this->device_height) height = this->device_height;
	
	NSRect contentRect = NSMakeRect(0, 0, width, height);
	
	/* Check if we should recreate the window */
	if (this->window == nil) {
		/* Set the window style */
		unsigned int style = NSWindowStyleMaskTitled;
		style |= (NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskClosable);
		style |= NSWindowStyleMaskResizable;
		
		/* Manually create a window, avoids having a nib file resource */
		this->window = [ [ OTTD_CocoaWindow alloc ]
						initWithContentRect:contentRect
						styleMask:style
						backing:NSBackingStoreBuffered
						defer:NO ];
		
		if (this->window == nil) {
			DEBUG(driver, 0, "Could not create the Cocoa window.");
			this->setup = false;
			return false;
		}
		
		/* Add built in full-screen support when available (OS X 10.7 and higher)
		 * This code actually compiles for 10.5 and later, but only makes sense in conjunction
		 * with the Metal fullscreen support as found only in 10.7 and later
		 */
		if ([this->window respondsToSelector:@selector(toggleFullScreen:)]) {
			NSWindowCollectionBehavior behavior = [ this->window collectionBehavior ];
			behavior |= NSWindowCollectionBehaviorFullScreenPrimary;
			[ this->window setCollectionBehavior:behavior ];
			
			NSButton* fullscreenButton = [ this->window standardWindowButton:NSWindowZoomButton ];
			[ fullscreenButton setAction:@selector(toggleFullScreen:) ];
			[ fullscreenButton setTarget:this->window ];
			
			[ this->window setCollectionBehavior: NSWindowCollectionBehaviorFullScreenPrimary ];
		}
		
		[ this->window setDriver:this ];
		
		char caption[50];
		snprintf(caption, sizeof(caption), "OpenTTD %s", _openttd_revision);
		NSString *nsscaption = [ [ NSString alloc ] initWithUTF8String:caption ];
		[ this->window setTitle:nsscaption ];
		[ this->window setMiniwindowTitle:nsscaption ];
		
		[ this->window setContentMinSize:NSMakeSize(640.0f, 480.0f) ];
		
		[ this->window setAcceptsMouseMovedEvents:YES ];
		[ this->window setViewsNeedDisplay:NO ];
		
		this->cocoaWindowDelegate = [ [ OTTD_CocoaWindowDelegate alloc ] init ];
		[ this->cocoaWindowDelegate setDriver:this ];
		[ this->window setDelegate: this->cocoaWindowDelegate ];
	} else {
		/* We already have a window, just change its size */
		[ this->window setContentSize:contentRect.size ];
		
		/* Ensure frame height - title bar height >= view height */
		contentRect.size.height = Clamp(height, 0, (int)[ this->window frame ].size.height - 22 /* 22 is the height of title bar of window*/);
		
		if (this->cocoaview != nil) {
			height = (int)contentRect.size.height;
			[ this->cocoaview setFrameSize:contentRect.size ];
		}
	}
	
	this->window_width = width;
	this->window_height = height;
	this->buffer_depth = bpp;
	
	[ this->window center ];
	
	/* Only recreate the view if it doesn't already exist */
	if (this->cocoaview == nil) {
		this->cocoaview = [ [ OTTD_MetalView alloc ] initWithFrame:contentRect ];
		if (this->cocoaview == nil) {
			DEBUG(driver, 0, "Could not create the Metal view.");
			this->setup = false;
			return false;
		}
		
		[ this->cocoaview setDriver:this ];
		
		[ (NSView*)this->cocoaview setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable ];
		[ this->window setContentView:cocoaview ];
		[ this->window makeKeyAndOrderFront:nil ];
	}
	
	this->SetupMetal();
	
	bool ret = WindowResized();
	
	this->setup = false;
	
	return ret;
}

void WindowMetalSubdriver::ChangeMetalResolution(int w, int h) {
	
}

void WindowMetalSubdriver::SetupMetal()
{
	if (((OTTD_MetalView*)this->cocoaview).cocoa_touch_layer == NULL) {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		CAMetalLayer *metalLayer = nil;
		MTLFeatureSet supportsFeatureSet = MTLFeatureSet_macOS_GPUFamily1_v1;
		
		if (device && [device supportsFeatureSet:supportsFeatureSet]) {
			metalLayer = [CAMetalLayer layer];
			metalLayer.device = device;
			metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
			metalLayer.framebufferOnly = YES;
		} else {
			return;
		}
		
		NSError *error = NULL;
		NSString *libraryPath = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"metallib"];
		id<MTLLibrary> library = [metalLayer.device newLibraryWithFile:libraryPath error:&error];
		
		MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
		pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"basic_vertex"];
		pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"basic_fragment"];
		pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
		
		float vertices[] = {
			-1.0, -1.0,
			-1.0, 1.0,
			1.0, -1.0,
			1.0, 1.0
		};
		
		pipelineState = [metalLayer.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
		commandQueue = [metalLayer.device newCommandQueue];
		vertexBuffer = [metalLayer.device newBufferWithBytes:&vertices length:sizeof(vertices) options:MTLResourceOptionCPUCacheModeDefault];
		if (error) {
			NSLog(@"Error initializing pipeline state: %@", error.localizedDescription);
			return;
		}
		metalLayer.frame = ((OTTD_MetalView*)this->cocoaview).bounds;
		((OTTD_MetalView*)this->cocoaview).cocoa_touch_layer = metalLayer;
		[((OTTD_MetalView*)this->cocoaview).layer addSublayer:metalLayer];
	}
}

void WindowMetalSubdriver::BlitIndexedToView32(int left, int top, int right, int bottom)
{
	const uint32 *pal   = this->palette;
	const uint8  *src   = (uint8*)this->pixel_buffer;
	uint32       *dst   = (uint32*)this->pixel_buffer;
	uint          width = this->window_width;
	uint          pitch = this->window_width;
	
	for (int y = top; y < bottom; y++) {
		for (int x = left; x < right; x++) {
			dst[y * pitch + x] = pal[src[y * width + x]];
		}
	}
}


WindowMetalSubdriver::WindowMetalSubdriver()
{
	this->window_width  = 0;
	this->window_height = 0;
	this->buffer_depth  = 0;
	this->pixel_buffer  = NULL;
	this->active        = false;
	this->setup         = false;
	
	this->window = nil;
	this->cocoaview = nil;
	
	this->cgcontext = NULL;
	
	this->num_dirty_rects = MAX_DIRTY_RECTS;
}

WindowMetalSubdriver::~WindowMetalSubdriver()
{
	/* Release window mode resources */
	if (this->window != nil) [ this->window close ];
	
	CGContextRelease(this->cgcontext);
	
	free(this->pixel_buffer);
	
	if (commandQueue) {
		commandQueue = nil;
		pipelineState = nil;
		vertexBuffer = nil;
	}
}

void WindowMetalSubdriver::Draw(bool force_update)
{
	PerformanceMeasurer framerate(PFE_VIDEO);
}

void WindowMetalSubdriver::MakeDirty(int left, int top, int width, int height) {}

void WindowMetalSubdriver::UpdatePalette(uint first_color, uint num_colors) {}

uint WindowMetalSubdriver::ListModes(OTTD_Point *modes, uint max_modes)
{
	return QZ_ListModes(modes, max_modes, kCGDirectMainDisplay, this->buffer_depth);
}

bool WindowMetalSubdriver::ChangeResolution(int w, int h, int bpp)
{
	int old_width  = this->window_width;
	int old_height = this->window_height;
	int old_bpp    = this->buffer_depth;
	
	if (this->SetVideoMode(w, h, bpp)) return true;
	if (old_width != 0 && old_height != 0) this->SetVideoMode(old_width, old_height, old_bpp);
	
	return false;
}

/* Convert local coordinate to window server (CoreGraphics) coordinate */
CGPoint WindowMetalSubdriver::PrivateLocalToCG(NSPoint *p)
{
	p->y = this->window_height - p->y;
	*p = [ this->cocoaview convertPoint:*p toView:nil ];

	if ([ this->window respondsToSelector:@selector(convertRectToScreen:) ]) {
		*p = [ this->window convertRectToScreen:NSMakeRect(p->x, p->y, 0, 0) ].origin;
	}
	
	p->y = this->device_height - p->y;
	
	CGPoint cgp;
	cgp.x = p->x;
	cgp.y = p->y;
	
	return cgp;
}

NSPoint WindowMetalSubdriver::GetMouseLocation(NSEvent *event)
{
	NSPoint pt;
	
	if ( [ event window ] == nil) {
		if ([ [ this->cocoaview window ] respondsToSelector:@selector(convertRectFromScreen:) ]) {
			pt = [ this->cocoaview convertPoint:[ [ this->cocoaview window ] convertRectFromScreen:NSMakeRect([ event locationInWindow ].x, [ event locationInWindow ].y, 0, 0) ].origin fromView:nil ];
		}
	} else {
		pt = [ event locationInWindow ];
	}
	
	pt.y = this->window_height - pt.y;
	
	return pt;
}

bool WindowMetalSubdriver::MouseIsInsideView(NSPoint *pt)
{
	return [ cocoaview mouse:*pt inRect:[ this->cocoaview bounds ] ];
}


/* This function makes the *game region* of the window 100% opaque.
 * The genie effect uses the alpha component. Otherwise,
 * it doesn't seem to matter what value it has.
 */
void WindowMetalSubdriver::SetPortAlphaOpaque()
{
	uint32 *pixels = (uint32*)this->pixel_buffer;
	uint32  pitch  = this->window_width;
	
	for (int y = 0; y < this->window_height; y++)
		for (int x = 0; x < this->window_width; x++) {
			pixels[y * pitch + x] |= 0xFF000000;
		}
}

bool WindowMetalSubdriver::WindowResized()
{
	if (this->window == nil || this->cocoaview == nil) return true;
	
	NSRect newframe = [ this->cocoaview frame ];
	
	this->window_width = (int)newframe.size.width;
	this->window_height = (int)newframe.size.height;
	
	_screen.width = window_width;
	_screen.height = window_height;
	
	OTTD_MetalView* view = ((OTTD_MetalView*)this->cocoaview);
	CAMetalLayer *metalLayer = view.cocoa_touch_layer;
	
	[view.queue cancelAllOperations];
	
	int pitch = this->window_width;
	
	if (pitch % 64) {
		pitch += (64 - (pitch % 64));
	}
	
	_screen.pitch = pitch;
	
	Blitter *blitter = BlitterFactory::GetCurrentBlitter();
	assert(blitter->GetScreenDepth() == 32);
	size_t buffer_size = pitch * _screen.height * 4;
	
	if (pixel_buffer) {
		free(pixel_buffer);
	}
	
	if (buffer_size % 4096) {
		buffer_size += (4096 - (buffer_size % 4096));
	}
	
	pixel_buffer = malloc(buffer_size*2);
	
	textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:_screen.width height:_screen.height mipmapped:NO];
	metalLayer.drawableSize = CGSizeMake(_screen.width, _screen.height);
	
	_screen.dst_ptr = pixel_buffer;
	_fullscreen = IsFullscreen();
	
	BlitterFactory::GetCurrentBlitter()->PostResize();
	GameSizeChanged();
	
	/* Redraw screen */
	this->num_dirty_rects = MAX_DIRTY_RECTS;
	
	return true;
}


CocoaSubdriver *MTL_CreateWindowMetalSubdriver(int width, int height, int bpp)
{
	if (!MacOSVersionIsAtLeast(10, 4, 0)) {
		DEBUG(driver, 0, "The cocoa Metal subdriver requires Mac OS X 10.4 or later.");
		return NULL;
	}
	
	if (bpp != 8 && bpp != 32) {
		DEBUG(driver, 0, "The cocoa Metal subdriver only supports 8 and 32 bpp.");
		return NULL;
	}
	
	WindowMetalSubdriver *ret = new WindowMetalSubdriver();
	
	if (!ret->ChangeResolution(width, height, bpp)) {
		delete ret;
		return NULL;
	}
	
	return ret;
}


#endif /* MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4 */
#endif /* ENABLE_COCOA_METAL */
#endif /* WITH_COCOA */

