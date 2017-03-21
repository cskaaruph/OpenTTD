//
//  ios.cpp
//  OpenTTD
//
//  Created by Jesús A. Álvarez on 02/03/2017.
//  Copyright © 2017 OpenTTD. All rights reserved.
//

#import <UIKit/UIKit.h>

#include "stdafx.h"
#include "openttd.h"
#include "random_func.hpp"
#include "debug.h"
#include "fileio_func.h"
#include "fios.h"

#include <dirent.h>
#include <unistd.h>
#include <sys/stat.h>
#include <time.h>
#include <signal.h>
#include <sys/mount.h>

#include "safeguards.h"

const char * _globalDataDir;

extern "C" {
	extern char ***_NSGetArgv(void);
	extern int *_NSGetArgc(void);
}

bool FiosIsRoot(const char *path)
{
    return path[1] == '\0';
}

void FiosGetDrives(FileList &file_list)
{
	// Add link to Documents
    FiosItem *fios = file_list.Append();
    fios->type = FIOS_TYPE_DIRECT;
    fios->mtime = 0;
    strecpy(fios->name, _searchpaths[SP_PERSONAL_DIR], lastof(fios->name));
    strecpy(fios->title, "~/Documents", lastof(fios->title));
    return;
}

bool FiosGetDiskFreeSpace(const char *path, uint64 *tot)
{
    uint64 free = 0;
    struct statfs s;
    
    if (statfs(path, &s) != 0) return false;
    free = (uint64)s.f_bsize * s.f_bavail;
    if (tot != NULL) *tot = free;
    return true;
}

bool FiosIsValidFile(const char *path, const struct dirent *ent, struct stat *sb)
{
    char filename[MAX_PATH];
    int res;
    assert(path[strlen(path) - 1] == PATHSEPCHAR);
    if (strlen(path) > 2) assert(path[strlen(path) - 2] != PATHSEPCHAR);
    res = seprintf(filename, lastof(filename), "%s%s", path, ent->d_name);
    
    /* Could we fully concatenate the path and filename? */
    if (res >= (int)lengthof(filename) || res < 0) return false;
    
    return stat(filename, sb) == 0;
}

bool FiosIsHiddenFile(const struct dirent *ent)
{
    return ent->d_name[0] == '.';
}

const char *FS2OTTD(const char *name) {return name;}
const char *OTTD2FS(const char *name) {return name;}

void ShowInfo(const char *str)
{
    fprintf(stderr, "%s\n", str);
}

const char *OSErrorMessage = nullptr;

void ShowOSErrorBox(const char *buf, bool system)
{
	if ([UIApplication sharedApplication] == nil) {
		OSErrorMessage = buf;
		UIApplicationMain(*_NSGetArgc(), *_NSGetArgv(), nil, @"AppDelegate");
	} else {
		[[UIApplication sharedApplication].delegate performSelector:@selector(showErrorMessage:) withObject:@(buf)];
	}
}

/**
 * Determine and return the current user's locale.
 */
const char *GetCurrentLocale(const char *)
{
    static char retbuf[32] = { '\0' };
    NSUserDefaults *defs = [ NSUserDefaults standardUserDefaults ];
    NSArray *languages = [ defs objectForKey:@"AppleLanguages" ];
    NSString *preferredLang = [ languages objectAtIndex:0 ];
    [ preferredLang getCString:retbuf maxLength:32 encoding:NSASCIIStringEncoding ];
    return retbuf;
}

/** Set the application's bundle directory.
 *
 * Set the relevant search paths for iOS (bundle and documents)
 */
void cocoaSetApplicationBundleDir()
{
	NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject.stringByStandardizingPath stringByAppendingString:@"/"];
	_searchpaths[SP_FIRST_DIR] = NULL;
	_searchpaths[SP_PERSONAL_DIR] = stredup(documentsDirectory.fileSystemRepresentation);
	_searchpaths[SP_BINARY_DIR] = NULL;
	_searchpaths[SP_INSTALLATION_DIR] = NULL;
	_searchpaths[SP_APPLICATION_BUNDLE_DIR] = stredup(_globalDataDir);
}

bool GetClipboardContents(char *buffer, const char *last)
{
    UIPasteboard *pasteboard = [ UIPasteboard generalPasteboard ];
    if (pasteboard.hasStrings)
    {
        strecpy(buffer, pasteboard.string.UTF8String, last);
        return true;
    } else
    {
        return false;
    }
}

void CSleep(int milliseconds)
{
    usleep(milliseconds * 1000);
}

bool QZ_CanDisplay8bpp()
{
    return false;
}

void OSOpenBrowser(const char *url)
{
    [[ UIApplication sharedApplication ] openURL: [ NSURL URLWithString:@(url)] ];
}

int main(int argc, char * argv[])
{
    @autoreleasepool
    {
        _globalDataDir = [[ NSBundle mainBundle ].resourcePath stringByAppendingString:@"/"].fileSystemRepresentation;
        
        SetRandomSeed(time(NULL));
        
        signal(SIGPIPE, SIG_IGN);
		
		return openttd_main(1, argv);
    }
}
