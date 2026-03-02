//
//  FX-Live-Mac-Bridging-Header.h
//  FX-Live-Mac
//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "AudioEngine.h"
#import "EQSettings.h"
#import "DSPSettings.h"
#import "SwiftTryCatch.h"

// Function to set the show folder path from Swift, used by audioEngine.m
void setMacOSShowFolder(NSString* _Nullable path);
#import "SwiftTryCatch.h"
