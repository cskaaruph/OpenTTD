//
//  MIDIManager.h
//  OpenTTD
//
//  Created by Christian Skaarup Enevoldsen on 18/08/2019.
//  Copyright © 2019 OpenTTD. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MIDIManager : NSObject

+ (id)sharedManager;

- (void)loadManager;
- (void)loadSongWith:(NSURL *)url;
- (void)play;
- (void)stop;
- (BOOL)playing;
- (void)setVolume:(UInt8)volume;

@end

NS_ASSUME_NONNULL_END
