//
//  ViewController.m
//  ExampleMac
//
//  Created by Adam Bard on 2016-07-26.
//  Copyright © 2016 Tapstream. All rights reserved.
//

#import "ViewController.h"
#import "Globals.h"
#import "TSDefaultHttpClient.h"
#import "TapstreamMac.h"

@interface ViewController()
@property (unsafe_unretained) IBOutlet NSTextView *textView;
@property(readwrite) id<TSHttpClient> httpClient;
@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	self.httpClient = [TSDefaultHttpClient httpClientWithConfig:[Globals config]];

	// Do any additional setup after loading the view.
}

- (void)setRepresentedObject:(id)representedObject {
	[super setRepresentedObject:representedObject];

	// Update the view, if already loaded.
}

- (void)logMessage:(NSString*)msg
{
	[[self textView] setString:msg];
}

- (void)appendMessage:(NSString*)msg
{
	[[self textView] setString:[NSString stringWithFormat:@"%@\n%@",
								[[self textView] string],
								msg]];
}

- (IBAction)generateConversion:(id)sender {
	NSString* accountName = [Globals accountName];
	NSString* tsid = [Globals hitSessionId];
	NSURL* hitURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.tapstream.com/%@/hit/?__tsid_override=1&__tsid=%@",
						  accountName,
										  tsid]];
	[self logMessage:@"Generating conversion..."];

	[[self httpClient] request:hitURL completion:^(TSResponse* resp) {
		if(resp == nil || [resp failed])
		{
			[self appendMessage:@"Could not create hit."];
			return;
		}

		TSEvent* event = [TSEvent eventWithName:@"examplemac-gen-conversion" oneTimeOnly:NO];
		[[TSTapstream instance] fireEvent:event];
		[self appendMessage:@"Done!"];
	}];
}

- (IBAction)lookupTimeline:(id)sender {
	[self logMessage:@"Fetching timeline..."];

	[[TSTapstream instance] lookupTimeline:^(TSTimelineApiResponse* response) {
		if(response == nil || [response failed])
		{
			[self logMessage:@"Timeline request failed!"];
			return;
		}

		NSDictionary* event = [response.events lastObject];

		if(event != nil)
		{
			NSString* tracker = [event objectForKey:@"tracker"];
			[self logMessage:[NSString stringWithFormat:@"Hits: %lu, Events: %lu, (Last Event: %@)",
							  (unsigned long)[response.hits count],
							  (unsigned long)[response.events count],
							  tracker]];
		}
	}];
}

- (IBAction)fireEventWithCustomParam:(id)sender {
	TSEvent* event = [TSEvent eventWithName:@"event-with-custom-params" oneTimeOnly:false];
	[event addValue:@"some-value" forKey:@"some-key"];
	[[TSTapstream instance] fireEvent:event];

	[self logMessage:[NSString stringWithFormat:@"Event Fired: %@", event.name]];
}

- (IBAction)firePurchaseEvent:(id)sender {
	TSEvent* event = [TSEvent eventWithTransactionId: @"my-transaction-id"
										   productId: @"my-product-id"
											quantity: 12
										priceInCents: 1000
											currency: @"USD"];
	[[TSTapstream instance] fireEvent:event];
	[self logMessage:[NSString stringWithFormat:@"Event Fired: %@", event.name]];
}

- (IBAction)firePurchaseEventNoPrice:(id)sender {
	TSEvent* event = [TSEvent eventWithTransactionId: @"my-transaction-id"
										   productId: @"my-product-id"
											quantity: 12];
	[[TSTapstream instance] fireEvent:event];
	[self logMessage:[NSString stringWithFormat:@"Event Fired: %@", event.name]];
}

- (IBAction)resetState:(id)sender {
	// Reset internal tapstream storage
	[[NSUserDefaults standardUserDefaults]
	 setPersistentDomain:[NSDictionary dictionary]
	 forName:@"__tapstream"];

	// Reset stored hit session id
	[[NSUserDefaults standardUserDefaults]
	 setObject:nil
	 forKey:@"__tsid_override"];

	// Regenerate hit session id
	TSConfig* conf = [Globals config];
	[Globals createWithConfig:conf];

	// Recreate tapstream
	[TSTapstream createWithConfig:conf];
}

@end
