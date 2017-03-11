//
//  GameInputView.m
//  OpenTTD
//
//  Created by Jesús A. Álvarez on 06/03/2017.
//  Copyright © 2017 OpenTTD. All rights reserved.
//

#import "GameInputView.h"
#import "AppDelegate.h"
#include "stdafx.h"
#include "openttd.h"
#include "debug.h"
#include "cocoa_touch_v.h"
#include "gfx_func.h"
#include "window_gui.h"
#include "zoom_func.h"

extern CALayer *_cocoa_touch_layer;

@implementation GameInputView
{
	int start_scrollpos_x, start_scrollpos_y;
	CGFloat wheelLevel;
	Window *panWindow;
}

- (void)awakeFromNib {
	[super awakeFromNib];
	UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
	panRecognizer.minimumNumberOfTouches = 2;
	[self addGestureRecognizer:panRecognizer];
	
	UIPinchGestureRecognizer *pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
	[self addGestureRecognizer:pinchRecognizer];
}

- (void)handlePanGesture:(UIPanGestureRecognizer*)recognizer {
	Point point;
	switch (recognizer.state) {
		case UIGestureRecognizerStateBegan:
			point = [self gamePoint:[recognizer locationInView:self]];
			panWindow = FindWindowFromPt(point.x, point.y);
			if (panWindow->viewport) {
				// panning
				start_scrollpos_x = panWindow->viewport->dest_scrollpos_x;
				start_scrollpos_y = panWindow->viewport->dest_scrollpos_y;
			} else {
				// mouse wheel
				_cursor.UpdateCursorPosition(point.x, point.y, false);
				_left_button_down = false;
				_left_button_clicked = false;
				wheelLevel = 0.0;
			}
		case UIGestureRecognizerStateChanged:
			point = [self gamePoint:[recognizer translationInView:self]];
			if (panWindow->viewport && _game_mode != GM_MENU) {
				// panning
				int x = -point.x;
				int y = -point.y;
				panWindow->viewport->dest_scrollpos_x = start_scrollpos_x + ScaleByZoom(x, panWindow->viewport->zoom);
				panWindow->viewport->dest_scrollpos_y = start_scrollpos_y + ScaleByZoom(y, panWindow->viewport->zoom);
			} else if (panWindow->viewport == NULL) {
				// mouse wheel
				int increment = (wheelLevel - point.y) / (5 * (4 >> _gui_zoom));
				[self handleMouseWheelEvent:increment];
				wheelLevel = point.y;
			}
			break;
		case UIGestureRecognizerStateEnded:
		case UIGestureRecognizerStateCancelled:
			panWindow = NULL;
		default:
			break;
	}
}

- (void)handlePinchGesture:(UIPinchGestureRecognizer*)recognizer {
	Point point = [self gamePoint:[recognizer locationInView:self]];

	switch (recognizer.state) {
		case UIGestureRecognizerStateEnded:
		case UIGestureRecognizerStateCancelled:
			wheelLevel = 0.0;
			break;
		case UIGestureRecognizerStateBegan:
			_cursor.UpdateCursorPosition(point.x, point.y, false);
			_left_button_down = false;
			_left_button_clicked = false;
			wheelLevel = recognizer.scale;
			break;
		case UIGestureRecognizerStateChanged:
			if (fabs(recognizer.scale - wheelLevel) > 0.25) {
				int increment = recognizer.scale < wheelLevel ? 1 : -1;
				[self handleMouseWheelEvent:increment];
				wheelLevel = recognizer.scale;
			}
		default:
			break;
	}
}

- (void)handleMouseWheelEvent:(int)increment {
	_cursor.wheel += increment;
	HandleMouseEvents();
}

- (Point)gamePoint:(CGPoint)point {
	CGSize size = self.bounds.size;
	Point gamePoint = {
		.x = (int)(point.x * (_screen.width / size.width)),
		.y = (int)(point.y * (_screen.height / size.height))
	};
	return gamePoint;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
	UITouch *touch = touches.anyObject;
	Point point = [self gamePoint:[touch locationInView:self]];
	_cursor.UpdateCursorPosition(point.x, point.y, false);
	_left_button_down = true;
	HandleMouseEvents();
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
	UITouch *touch = touches.anyObject;
	Point point = [self gamePoint:[touch locationInView:self]];
	_cursor.UpdateCursorPosition(point.x, point.y, false);
	_left_button_down = true;
	HandleMouseEvents();
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
	UITouch *touch = touches.anyObject;
	Point point = [self gamePoint:[touch locationInView:self]];
	_cursor.UpdateCursorPosition(point.x, point.y, false);
	_left_button_down = false;
	_left_button_clicked = false;
	HandleMouseEvents();
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
	UITouch *touch = touches.anyObject;
	Point point = [self gamePoint:[touch locationInView:self]];
	_cursor.UpdateCursorPosition(point.x, point.y, false);
	_left_button_down = false;
	_left_button_clicked = false;
	HandleMouseEvents();
}


@end
