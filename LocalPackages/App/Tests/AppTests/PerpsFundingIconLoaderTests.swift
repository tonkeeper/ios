@testable import App
import Foundation
import XCTest

@MainActor
final class PerpsFundingIconLoaderTests: XCTestCase {
    func testWalletImageTakesPrecedenceOverCatalog() async {
        let expected = URL(string: "https://example.com/wallet.png")
        let loader = PerpsFundingIconLoader { _ in
            XCTFail("A wallet image does not need a catalog lookup")
            return nil
        }
        let icon = await loader.iconURL(assetId: "USDC", walletImage: " https://example.com/wallet.png ")
        XCTAssertEqual(icon, expected)
    }

    func testEmptyOrInvalidWalletImageUsesTheSameCachedCatalogIcon() async {
        let expected = URL(string: "https://example.com/catalog.png")
        var requests = 0
        let loader = PerpsFundingIconLoader { _ in
            requests += 1
            return expected
        }
        for image in [nil, "", " ", "relative/path"] {
            let icon = await loader.iconURL(assetId: "USDC", walletImage: image)
            XCTAssertEqual(icon, expected)
        }
        XCTAssertEqual(requests, 1)
    }

    func testMissingCatalogIconIsCachedButDoesNotHideANewWalletImage() async {
        var requests = 0
        let loader = PerpsFundingIconLoader { _ in requests += 1; return nil }
        let first = await loader.iconURL(assetId: "usdc", walletImage: nil)
        let second = await loader.iconURL(assetId: "USDC", walletImage: "")
        XCTAssertNil(first)
        XCTAssertNil(second)
        XCTAssertEqual(requests, 1)
        let wallet = await loader.iconURL(assetId: "usdc", walletImage: "https://example.com/wallet.png")
        XCTAssertEqual(wallet, URL(string: "https://example.com/wallet.png"))
        XCTAssertEqual(requests, 1)
    }

    func testConcurrentScreenAndPickerRequestsShareTheCatalogLookup() async {
        let started = expectation(description: "catalog started")
        let secondStarted = expectation(description: "picker started")
        var finish: CheckedContinuation<URL?, Never>?
        var requests = 0
        let loader = PerpsFundingIconLoader { _ in
            requests += 1
            return await withCheckedContinuation {
                finish = $0
                started.fulfill()
            }
        }
        let screen = Task { await loader.iconURL(assetId: "usdc", walletImage: nil) }
        await fulfillment(of: [started], timeout: 1)
        let picker = Task {
            secondStarted.fulfill()
            return await loader.iconURL(assetId: "USDC", walletImage: "")
        }
        await fulfillment(of: [secondStarted], timeout: 1)
        XCTAssertEqual(requests, 1)
        let expected = URL(string: "https://example.com/catalog.png")
        finish?.resume(returning: expected)
        let screenIcon = await screen.value
        let pickerIcon = await picker.value
        XCTAssertEqual(screenIcon, expected)
        XCTAssertEqual(pickerIcon, expected)
        XCTAssertEqual(requests, 1)
    }
}
