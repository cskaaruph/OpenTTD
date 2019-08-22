//
//  GameViewController.m
//  OpenTTD_Mac
//
//  Created by Christian Skaarup Enevoldsen on 20/08/2019.
//  Copyright © 2019 OpenTTD. All rights reserved.
//

#import "GameViewController.h"
#import "AppDelegate.h"

extern CALayer *_cocoa_touch_layer;

@implementation GameViewController {
    MTKView *_view;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _view = (MTKView *)self.view;

    _view.device = MTLCreateSystemDefaultDevice();

    if(!_view.device)
    {
        NSLog(@"Metal is not supported on this device");
        self.view = [[NSView alloc] initWithFrame:self.view.frame];
        return;
    }

	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		_cocoa_touch_layer.frame = self.view.bounds;
		[self.view.layer addSublayer:_cocoa_touch_layer];
		[[AppDelegate sharedInstance] resizeGameView:self.view.bounds.size];
	});
	
	[[AppDelegate sharedInstance] setupOpenTTD];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id)coordinator {
	[[AppDelegate sharedInstance] resizeGameView:size];
}

- (void)viewDidLayoutSubviews {
	_cocoa_touch_layer.frame = self.view.bounds;
}

- (BOOL)prefersStatusBarHidden {
	return YES;
}

@end
