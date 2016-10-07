//
//  AppDelegate.m
//  ExampleMac
//
//  Created by Adam Bard on 2016-07-26.
//  Copyright © 2016 Tapstream. All rights reserved.
//

#import "AppDelegate.h"
#import "Globals.h"
#import "TapstreamMac.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application

	TSConfig* config = [TSConfig configWithAccountName:@"sdktest" sdkSecret:@"YGP2pezGTI6ec48uti4o1w"];
	[Globals createWithConfig:config];
	[TSTapstream createWithConfig:config];
	
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
}

@end
