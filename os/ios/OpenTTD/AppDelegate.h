//
//  AppDelegate.h
//  OpenTTD
//
//  Created by Jesús A. Álvarez on 28/02/2017.
//  Copyright © 2017 OpenTTD. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_MAC && !TARGET_OS_SIMULATOR
#import <AppKit/AppKit.h>
#import <Cocoa/Cocoa.h>
@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (assign) IBOutlet NSWindow *window;
#else
#import <UIKit/UIKit.h>
@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
#endif

+ (instancetype)sharedInstance;
- (void)resizeGameView:(CGSize)size;
- (void)startGameLoop;
- (void)showErrorMessage:(NSString*)message;
- (void)setupOpenTTD;

@end

