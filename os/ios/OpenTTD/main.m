//
//  main.m
//  OpenTTD
//
//  Created by Jesús A. Álvarez on 28/02/2017.
//  Copyright © 2017 OpenTTD. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

const char * _globalDataDir;

int main(int argc, char * argv[]) {
    @autoreleasepool {
        _globalDataDir = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"data"].fileSystemRepresentation;
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
