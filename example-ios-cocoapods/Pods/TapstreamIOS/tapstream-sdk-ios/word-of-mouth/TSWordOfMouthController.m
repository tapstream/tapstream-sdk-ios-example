//  Copyright © 2016 Tapstream. All rights reserved.

#import "TSWordOfMouthController.h"

#import "TSOfferViewController.h"
#import "TSTapstream.h"
#import "TSLogging.h"
#import "TSOfferStrategy.h"
#import "TSRewardStrategy.h"
#import "TSHttpClient.h"
#import "TSURLBuilder.h"

#define kTSInstallDateKey @"__tapstream_install_date"
#define kTSLastOfferImpressionTimesKey @"__tapstream_last_offer_impression_times"


@interface TSReward()
- (void)consume;
@end



@interface TSWordOfMouthController()
/*
@property(strong, nonatomic) NSString *secret;
@property(strong, nonatomic) NSString *bundle;
@property(strong, nonatomic) NSString *uuid;
*/
@property(strong, nonatomic) TSConfig* config;
@property(strong, nonatomic) TSOfferViewController *offerViewController;
@property(nonatomic, strong) id<TSOfferStrategy> offerStrategy;
@property(nonatomic, strong) id<TSRewardStrategy> rewardStrategy;
@property(strong, nonatomic) id<TSHttpClient> httpClient;
@property(strong, nonatomic) id<TSPlatform> platform;

@end



@implementation TSWordOfMouthController


- (instancetype)initWithConfig:(TSConfig*)config
					  platform:(id<TSPlatform>)platform
				 offerStrategy:(id<TSOfferStrategy>)offerStrategy
				rewardStrategy:(id<TSRewardStrategy>)rewardStrategy
					httpClient:(id<TSHttpClient>)httpClient
{
    if(self = [super init]) {
		self.config = config;
		self.platform = platform;
		self.offerStrategy = offerStrategy;
		self.rewardStrategy = rewardStrategy;
		self.httpClient = httpClient;
    }
    return self;
}

- (void)showOffer:(TSOffer *)offer parentViewController:(UIViewController *)parentViewController;
{
    if(offer && parentViewController) {
        self.offerViewController = [TSOfferViewController controllerWithOffer:offer delegate:self];
        self.offerViewController.view.frame = parentViewController.view.bounds;
        [parentViewController addChildViewController:self.offerViewController];
        [UIView transitionWithView:parentViewController.view
                          duration:0.3
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
                            [parentViewController.view addSubview:self.offerViewController.view];
                            [self.offerViewController didMoveToParentViewController:parentViewController];
                        }
                        completion:NULL];

        [self showedOffer:offer.ident];
		[self.offerStrategy registerOfferShown:(TSOffer*)offer];
	}
}


- (void)getOfferForInsertionPoint:(NSString *)insertionPoint completion:(void (^)(TSOfferApiResponse *))callback
{
	[TSLogging logAtLevel:kTSLoggingInfo
				   format:@"Requesting offer for insertion point '%@'", insertionPoint];

	if(callback == nil)
	{
		return;
	}

	// First, check for cached offer
	NSString* sessionId = [self.platform getSessionId];
	TSOffer *offer = [self.offerStrategy cachedOffer:insertionPoint sessionId:sessionId];

	if(offer != nil) {
		if([self.offerStrategy eligible:offer])
		{
			callback([TSOfferApiResponse offerApiResponseWithOffer:offer]);
		}
		else
		{
			TSResponse* ineligibleResponse = [TSResponse responseWithStatus:-1 message:@"Cached offer is not eligible" data:nil];
			callback([TSOfferApiResponse offerApiResponseWithResponse:ineligibleResponse sessionId:sessionId]);
		}
		return;
	}

	NSURL* url = [TSURLBuilder makeOfferURL:self.config
									 bundle:[self.platform getBundleIdentifier]
							 insertionPoint:insertionPoint];

	[self.httpClient request:url completion:^(TSResponse* response){

		[TSLogging logAtLevel:kTSLoggingInfo
					   format:@"Offers request complete (status %d)",
		 [response status]];

		TSOfferApiResponse* offerResponse = [TSOfferApiResponse
											 offerApiResponseWithResponse:response
											 sessionId:[self.platform getSessionId]];
		if([offerResponse failed])
		{
			[TSLogging logAtLevel:kTSLoggingWarn format:[TSError messageForError:[offerResponse error]]];
		}
		else
		{
			[self.offerStrategy registerOfferRetrieved:[offerResponse offer] forInsertionPoint:insertionPoint];

			if(![self.offerStrategy eligible:[offerResponse offer]])
			{
				// Replace offerResponse with invalidated one
				TSResponse* ineligibleResponse = [TSResponse responseWithStatus:-1 message:@"Cached offer is not eligible" data:nil];
				offerResponse = [TSOfferApiResponse offerApiResponseWithResponse:ineligibleResponse sessionId:sessionId];
				[TSLogging logAtLevel:kTSLoggingInfo format:@"Offer id=%d ineligible", [offer ident]];
			}
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			callback(offerResponse);
		});

	}];

}


- (void)getRewardList:(void(^)(TSRewardApiResponse*))completion
{

	NSURL* url = [TSURLBuilder makeRewardListURL:self.config sessionId:[self.platform getSessionId]];
	[self.httpClient request:url completion:^(TSResponse* response){
		TSRewardApiResponse* rewardResponse = [TSRewardApiResponse rewardApiResponseWithResponse:response strategy:self.rewardStrategy];
		if(![rewardResponse failed])
		{
			[TSLogging logAtLevel:kTSLoggingInfo
						   format:@"Checking %d returned potential rewards for quantity",
			 [[rewardResponse rewards] count]];
		}

		if(completion) {
			dispatch_sync(dispatch_get_main_queue(), ^() {
				completion(rewardResponse);
			});
		}
	}];
}

- (void)consumeReward:(TSReward*)reward
{
	[self.rewardStrategy registerClaimedReward:reward];
}

// TSWordOfMouthDelegate
- (void)showedOffer:(NSUInteger)offerId
{
    [self.delegate showedOffer:offerId];
}

- (void)dismissedOffer:(BOOL)accepted
{
    if(accepted) {
        TSOffer *offer = self.offerViewController.offer;
        UIViewController *parent = self.offerViewController.parentViewController;
        
        
        UIActivityViewController* c = [[UIActivityViewController alloc]
                                       initWithActivityItems:@[offer.message] applicationActivities:nil];

        
        __weak typeof(c) weakC = c;

		if([c respondsToSelector:@selector(setCompletionWithItemsHandler:)]){
			[c setCompletionWithItemsHandler:^(NSString* activityType, BOOL completed, NSArray* items, NSError* error){

				__strong typeof(weakC) strongC = weakC;

				if (completed) {
					NSString* cleanedType = activityType;

					if([activityType isEqualToString:UIActivityTypeMail]){
						cleanedType = @"email";
					}else if([activityType isEqualToString:UIActivityTypeMessage]){
						cleanedType = @"messaging";
					}else if([activityType isEqualToString:UIActivityTypePostToFacebook]){
						cleanedType = @"facebook";
					}else if([activityType isEqualToString:UIActivityTypePostToTwitter]){
						cleanedType = @"twitter";
					}

					[self completedShare:offer.ident socialMedium:cleanedType];
				}
				strongC.completionWithItemsHandler = nil;

			}];
		}else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
			[c setCompletionHandler:^(NSString* activityType, BOOL completed){

				__strong typeof(weakC) strongC = weakC;

				if (completed) {
					NSString* cleanedType = activityType;

					if([activityType isEqualToString:UIActivityTypeMail]){
						cleanedType = @"email";
					}else if([activityType isEqualToString:UIActivityTypeMessage]){
						cleanedType = @"messaging";
					}else if([activityType isEqualToString:UIActivityTypePostToFacebook]){
						cleanedType = @"facebook";
					}else if([activityType isEqualToString:UIActivityTypePostToTwitter]){
						cleanedType = @"twitter";
					}

					[self completedShare:offer.ident socialMedium:cleanedType];
				}
				strongC.completionHandler = nil;
				
			}];
#pragma clang diagnostic pop			
		}

		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
		{
			[parent presentViewController:c animated:YES completion:nil];
		}
		else if ([parent respondsToSelector:@selector(popoverPresentationController)])
		{
			c.popoverPresentationController.sourceRect = CGRectMake(parent.view.frame.size.width/2, parent.view.frame.size.height, 0, 0);
			c.popoverPresentationController.sourceView = parent.view;
			[parent presentViewController:c animated:YES completion:nil];
		}
		else
		{
			UIPopoverController *popup = [[UIPopoverController alloc] initWithContentViewController:c];
			[popup presentPopoverFromRect:CGRectMake(parent.view.frame.size.width/2, parent.view.frame.size.height, 0, 0)
								   inView:parent.view
				 permittedArrowDirections:UIPopoverArrowDirectionDown
								 animated:YES];
		}
    }

    // Clean up offer view
    [self.offerViewController willMoveToParentViewController:nil];
    [self.offerViewController.view removeFromSuperview];
    [self.offerViewController removeFromParentViewController];
    
    self.offerViewController = nil;
    [self.delegate dismissedOffer:accepted];
}

- (void)showedSharing:(NSUInteger)offerId
{
    [self.delegate showedSharing:offerId];
}

- (void)dismissedSharing
{}

- (void)completedShare:(NSUInteger)offerId socialMedium:(NSString *)medium
{
    [self.delegate completedShare:offerId socialMedium:medium];
}


@end
