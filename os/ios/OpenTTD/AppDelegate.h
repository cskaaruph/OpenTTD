//
//  AppDelegate.h
//  OpenTTD
//
//  Created by Jesús A. Álvarez on 28/02/2017.
//  Copyright © 2017 OpenTTD. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

+ (instancetype)sharedInstance;
- (void)resizeGameView:(CGSize)size;
- (void)startGameLoop;
- (void)showErrorMessage:(NSString*)message;

@end

