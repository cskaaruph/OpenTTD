/* $Id$ */

/*
 * This file is part of OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 2.
 * OpenTTD is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with OpenTTD. If not, see <http://www.gnu.org/licenses/>.
 */

/** @file cocoa_touch_v.mm Code related to the cocoa touch video driver(s). */

#import <UIKit/UIKit.h>
#ifdef WITH_METAL
#import <Metal/Metal.h>
#endif
#include "stdafx.h"
#import "cocoa_touch_v.h"

#include "openttd.h"
#include "debug.h"
#include "factory.hpp"
#include "gfx_func.h"
#include "fontcache.h"

static FVideoDriver_CocoaTouch iFVideoDriver_CocoaTouch;
VideoDriver_CocoaTouch *_cocoa_touch_driver = NULL;

#if defined(WITH_METAL) && TARGET_OS_SIMULATOR
// Metal is not supported in simulator
#undef WITH_METAL
#endif

#ifdef WITH_METAL
static id<MTLCommandQueue> commandQueue = nil;
static id<MTLRenderPipelineState> pipelineState = nil;
static id<MTLBuffer> vertexBuffer = nil;
static id<MTLBuffer> screenBuffer = nil;
static id<MTLTexture> screenTexture = nil;
#endif

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
	_fullscreen = true;
	_cocoa_touch_driver = this;
	
#ifdef WITH_METAL
	if (_cocoa_touch_layer == NULL) {
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		if (device && [device supportsFeatureSet:MTLFeatureSet_iOS_GPUFamily1_v1]) {
			CAMetalLayer *metalLayer = [CAMetalLayer layer];
			metalLayer.device = device;
			metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
			metalLayer.framebufferOnly = YES;
			_cocoa_touch_layer = metalLayer;
		}
	}
#endif
	if (_cocoa_touch_layer == NULL) {
		_cocoa_touch_layer = [CALayer layer];
	}

	this->ChangeResolution(_resolutions[0].width, _resolutions[0].height);

	return NULL;
}

void VideoDriver_CocoaTouch::Stop()
{
	if (this->context) {
		CGContextRelease(this->context);
	}
	if (this->pixel_buffer) {
		free(this->pixel_buffer);
		this->pixel_buffer = NULL;
	}
	_cocoa_touch_driver = NULL;
#ifdef WITH_METAL
	if (commandQueue) {
		commandQueue = nil;
		pipelineState = nil;
		vertexBuffer = nil;
		screenBuffer = nil;
		screenTexture = nil;
	}
#endif
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
	Blitter *blitter = BlitterFactory::GetCurrentBlitter();
	assert(blitter->GetScreenDepth() == 32);
	size_t buffer_size = _screen.pitch * _screen.height * 4;
	if (pixel_buffer) {
		free(pixel_buffer);
	}
	pixel_buffer = malloc(buffer_size);
	_screen.dst_ptr = pixel_buffer;
	
#ifdef WITH_METAL
	CAMetalLayer *metalLayer = ([_cocoa_touch_layer isKindOfClass:[CAMetalLayer class]] ? (CAMetalLayer *)_cocoa_touch_layer : nil);
	if (metalLayer) {
		if (commandQueue) {
			commandQueue = nil;
			pipelineState = nil;
			vertexBuffer = nil;
			screenBuffer = nil;
			screenTexture = nil;
		}
		
		metalLayer.drawableSize = CGSizeMake(w, h);
		NSError *error = nil;
		
		NSString *libraryPath = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"metallib"];
		id<MTLLibrary> library = [metalLayer.device newLibraryWithFile:libraryPath error:&error];
		
		MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
		pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"basic_vertex"];
		pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"basic_fragment"];
		pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
		
		MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:w height:h mipmapped:NO];
		
		float vertices[] = {
			-1.0, -1.0,
			-1.0, 1.0,
			1.0, -1.0,
			1.0, 1.0
		};
		
		pipelineState = [metalLayer.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
		commandQueue = [metalLayer.device newCommandQueue];
		vertexBuffer = [metalLayer.device newBufferWithBytes:&vertices length:sizeof(vertices) options:MTLResourceOptionCPUCacheModeDefault];
		screenBuffer = [metalLayer.device newBufferWithBytesNoCopy:pixel_buffer length:buffer_size options:MTLResourceOptionCPUCacheModeDefault deallocator:nil];
		screenTexture = [screenBuffer newTextureWithDescriptor:textureDescriptor offset:0 bytesPerRow:(textureDescriptor.width * 4)];
		
		if (error) {
			NSLog(@"Error initializing pipeline state: %@", error.localizedDescription);
		}
		
		BlitterFactory::GetCurrentBlitter()->PostResize();
		GameSizeChanged();
		return (error == nil);
	}
#endif
	
	// default to CoreGraphics
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
#ifdef WITH_METAL
	CAMetalLayer *metalLayer = ([_cocoa_touch_layer isKindOfClass:[CAMetalLayer class]] ? (CAMetalLayer *)_cocoa_touch_layer : nil);
	if (metalLayer) {
		if (CGSizeEqualToSize(metalLayer.drawableSize, CGSizeZero)) {
			NSLog(@"The drawable's size is empty");
			return;
		}
		
		id<CAMetalDrawable> drawable = [metalLayer nextDrawable];
		if (!drawable) {
			NSLog(@"The drawable cannot be nil");
			return;
		}
		
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
		return;
	}
#endif
	
	// CoreGraphics
	CGImageRef screenImage = CGBitmapContextCreateImage(this->context);
	_cocoa_touch_layer.contents = (__bridge id)screenImage;
	CGImageRelease(screenImage);
}

void VideoDriver_CocoaTouch::UpdatePalette(uint first_color, uint num_colors)
{
	
}
