@testable import App
import Foundation
import TKCore
import XCTest

final class DeeplinkOriginTests: XCTestCase {
    func test_perpsLinkFromTheLoyaltyPageOpensPerpsWithLoyaltyEntryPoint() {
        let urls = [
            KeeperDappBridge.loyaltyURL,
            KeeperDappBridge.loyaltyURL(referralCode: "CODE"),
        ]

        for url in urls {
            XCTAssertEqual(DeeplinkOrigin(dappURL: url).perpsEntryPoint, .loyalty, url.absoluteString)
        }
    }

    func test_perpsLinkFromAnotherDappOpensPerpsWithOtherEntryPoint() throws {
        let urls = [
            "https://trump.keeperwallet.com/",
            "https://battery.keeperwallet.com/",
            "http://loyalty.keeperwallet.com/",
            "https://app.ston.fi/",
        ]

        for string in urls {
            let url = try XCTUnwrap(URL(string: string))
            XCTAssertEqual(DeeplinkOrigin(dappURL: url).perpsEntryPoint, .other, string)
        }
    }

    func test_perpsLinkFromABannerOpensPerpsWithMainBannerEntryPoint() {
        XCTAssertEqual(DeeplinkOrigin.banner.perpsEntryPoint, .mainBanner)
    }
}
