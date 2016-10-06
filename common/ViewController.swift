//
//  ViewController.swift
//  example
//
//  Created by Adam Bard on 2016-05-13.
//  Copyright © 2016 Tapstream. All rights reserved.
//

import UIKit
import AdSupport


var httpClient : TSHttpClient = TSDefaultHttpClient.httpClient(with:Globals.config) as! TSHttpClient

class ViewController: UIViewController {
	// MARK: Properties

	@IBOutlet weak var exampleLog: UITextView!

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	func logMessage(_ m: String) {

		DispatchQueue.main.async(execute: {
			self.exampleLog.text = m
		})
	}

	func appendMessage(_ m: String) {
		DispatchQueue.main.async(execute: {
			self.exampleLog.text = self.exampleLog.text + "\n" + m
		})
	}

	@IBAction func generateConversion(_ sender: AnyObject) {
		let accountName = Globals.accountName

		self.logMessage("Generating conversion...")


		let tsid = Globals.hitSessionId
		if let hitUrl = URL(string:String(format:"https://api.tapstream.com/%@/hit/?__tsid_override=1&__tsid=%@",
		                                  accountName,
		                                  tsid)) {
			httpClient.request(hitUrl) { (response: TSResponse?) in
				if response == nil || response!.failed() {
					self.appendMessage("Could not create hit.")
					return
				}
				let event = TSEvent(name:"exampleapp-generate-conversion", oneTimeOnly:false)
				TSTapstream.instance().fire(event)
				self.appendMessage("Done!")
			}
		}
	}

	@IBAction func fireEventWithCustomParams(_ sender: AnyObject) {

		let event = TSEvent(name:"event-with-custom-params", oneTimeOnly:false)!
		event.addValue("some-value", forKey: "some-key")
		
		TSTapstream.instance().fire(event)

		self.logMessage(String.init(format: "Event Fired: %@", event.name))
	}

	@IBAction func firePurchaseEvent(_ sender: AnyObject) {
		let event = TSEvent(transactionId: "my-transaction-id",
		                    productId: "my-product-id",
		                    quantity: 12,
		                    priceInCents: 1000,
		                    currency: "USD")!
		TSTapstream.instance().fire(event)
		self.logMessage(String.init(format: "Event Fired: %@", event.name))

	}

	@IBAction func firePurchaseEventNoPrice(_ sender: AnyObject) {
		let event = TSEvent(transactionId: "my-transaction-id",
		                    productId: "my-product-id",
		                    quantity: 12)!
		TSTapstream.instance().fire(event);
		self.logMessage(String.init(format: "Event Fired: %@", event.name))
	}

	@IBAction func lookupWOMRewards(_ sender: AnyObject) {
		self.logMessage("Fetching rewards...")
		let wom = TSTapstream.wordOfMouthController() as! TSWordOfMouthController
		wom.getRewardList { (response: TSRewardApiResponse?) in
			if response == nil || response!.failed() {
				self.logMessage("Reward Request failed!")
				return
			}
			self.logMessage(String.init(format:"%d rewards retrieved", response!.rewards.count))
			for reward in response!.rewards {
				self.logMessage(String.init(format:"Reward: %@, %@", reward.insertionPoint, reward.sku))
			}
		}
	}

	@IBAction func lookupWOMOffer(_ sender: AnyObject) {
		self.logMessage("Fetching offer...")

		let wom = TSTapstream.wordOfMouthController() as! TSWordOfMouthController
		wom.getOfferForInsertionPoint("launch") { (resp: TSOfferApiResponse?) in
			if (resp == nil || resp!.failed()) {
				self.logMessage("No offer retrieved!")
				return
			}
			if let offer = resp?.offer {
				wom.show(offer, parentViewController: self)
				self.logMessage(String.init(format:"Offer retrieved (id=%d)", offer.ident))
			}
		}
	}

	@IBAction func lookupTimeline(_ sender: AnyObject) {
		self.logMessage("Fetching timeline...")
		TSTapstream.instance().lookupTimeline() { (response: TSTimelineApiResponse?) in
			if response == nil || response!.failed() {
				self.logMessage("Timeline request failed!")
				return
			}

			if let event = response!.events.last as? NSDictionary {
				if let tracker = event["tracker"] as? NSString {
					self.logMessage(String(format:"Hits: %d, Events: %d (Last Event: %@)",
					                         response!.hits.count,
					                         response!.events.count,
					                         tracker
						))
				}
			}
			
		}
	}

	@IBAction func testInAppLander(_ sender: AnyObject) {
		TSTapstream.instance().showLanderIfExists(withDelegate: nil)
		self.logMessage("Fired showLanderIfExistsWithDelegate")
	}


	@IBAction func clearState(_ sender: AnyObject) {
		self.logMessage("")
		UserDefaults.standard.setPersistentDomain([:], forName: "__tapstream")

		TSTapstream.create(with: Globals.config)
		Globals.hitSessionId = UUID().uuidString
		UserDefaults.standard.set(Globals.hitSessionId, forKey: "__tsid_override")
		//httpClient = TSDefaultHttpClient.httpClientWithConfig(Constants.config) as! TSHttpClient

		self.logMessage("Application state reset")
	}
}

