//
//  Globals.m
//  ExampleMac
//
//  Created by Adam Bard on 2016-10-06.
//  Copyright © 2016 Tapstream. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Globals.h"

static Globals* globals = nil;

@interface Globals()
@property(readwrite) TSConfig* config;
@property(readwrite) NSString* hitSessionId;
@end

@implementation Globals
+ (void)createWithConfig:(TSConfig*)config
{
	Globals* inst = [[Globals alloc] initWithConfig:config];
	globals = inst;
}

+ (instancetype)instance
{
	return globals;
}

- initWithConfig:(TSConfig*)config
{
	if((self = [super init]) != nil)
	{
		self.config = config;

		NSString* hitSession = [[NSUserDefaults standardUserDefaults] objectForKey:@"__tsid_override"];
		if(hitSession == nil)
		{
			hitSession = [[NSUUID UUID] UUIDString];
			[[NSUserDefaults standardUserDefaults] setObject:hitSession forKey:@"__tsid_override"];
		}
		self.hitSessionId = hitSession;
	}
	return self;
}

// Accessors for static var (created via createWithConfig)

+ (TSConfig*)config { return globals.config; }
+ (NSString*) accountName { return globals.config.accountName; }
+ (NSString*) hitSessionId { return globals.hitSessionId; }



@end