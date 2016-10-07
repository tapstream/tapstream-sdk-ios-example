//
//  Globals.h
//  ExampleMac
//
//  Created by Adam Bard on 2016-10-06.
//  Copyright © 2016 Tapstream. All rights reserved.
//

#ifndef Globals_h
#define Globals_h

#import "TapstreamMac.h"




@interface Globals : NSObject
+ (void)createWithConfig:(TSConfig*)config;
+ (instancetype)instance;
+ (TSConfig*)config;
+ (NSString*)accountName;
+ (NSString*)hitSessionId;
@end

#endif /* Globals_h */
