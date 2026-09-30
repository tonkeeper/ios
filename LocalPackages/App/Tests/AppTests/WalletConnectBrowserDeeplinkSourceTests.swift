@testable import App
@testable import KeeperCore
import TKScreenKit
import XCTest

final class WalletConnectBrowserDeeplinkSourceTests: XCTestCase {
    func testParserOverridesWalletConnectCustomSchemeSourceToBrowser() throws {
        let deeplink = try parser.parse(
            string: "tonkeeper://wc?uri=wc%3Atopic%402%3Frelay-protocol%3Dirn%26symKey%3Dabc",
            source: .browser
        )

        guard case let .walletConnect(payload) = deeplink else {
            return XCTFail("Expected WalletConnect deeplink")
        }

        XCTAssertEqual(payload.source, .browser)
        XCTAssertEqual(payload.uri, "wc:topic@2?relay-protocol=irn&symKey=abc")
    }

    func testParserOverridesRawWalletConnectDeeplinkSourceToBrowser() throws {
        let deeplink = try parser.parse(
            string: "wc:topic@2?relay-protocol=irn&symKey=abc",
            source: .browser
        )

        guard case let .walletConnect(payload) = deeplink else {
            return XCTFail("Expected WalletConnect deeplink")
        }

        XCTAssertEqual(payload.source, .browser)
        XCTAssertEqual(payload.uri, "wc:topic@2?relay-protocol=irn&symKey=abc")
    }

    func testParserKeepsSilentWalletConnectWakeUpWithBrowserSource() {
        XCTAssertThrowsError(try parser.parse(
            string: "tonkeeper://wc?uri=wc%3Atopic%402",
            source: .browser
        )) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .ignoredWalletConnectWakeUp)
        }
    }

    func testParserKeepsSilentWalletConnectSessionRequestRedirectWithBrowserSource() {
        XCTAssertThrowsError(try parser.parse(
            string: "tonkeeper://wc?requestId=1787580460495163&sessionTopic=topic",
            source: .browser
        )) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .ignoredWalletConnectWakeUp)
        }
    }

    func testNavigationHandlerCancelsSessionRequestRedirect() throws {
        let handler = TKWebViewControllerNavigationHandler(
            deeplinkParser: parser,
            openDeeplinkHandler: { _, _ in
                XCTFail("Session request redirect must not be opened as a deeplink")
            }
        )

        let url = try XCTUnwrap(URL(string: "tonkeeper://wc?requestId=1787580460495163&sessionTopic=topic"))
        let result = handler.handlerURLOpen(url)
        guard case .notOpen = result else {
            return XCTFail("Expected navigation to be cancelled")
        }
    }

    func testNavigationHandlerCancelsSilentWalletConnectWakeUp() throws {
        let handler = TKWebViewControllerNavigationHandler(
            deeplinkParser: parser,
            openDeeplinkHandler: { _, _ in
                XCTFail("Silent wake-up must not be opened as a deeplink")
            }
        )

        let result = try handler.handlerURLOpen(XCTUnwrap(URL(string: "tonkeeper://wc?uri=wc%3Atopic%402")))
        guard case .notOpen = result else {
            return XCTFail("Expected navigation to be cancelled")
        }
    }

    func testNavigationHandlerForwardsTheLinkCampaign() throws {
        var receivedUtm: UtmParameters?
        let handler = TKWebViewControllerNavigationHandler(
            deeplinkParser: parser,
            openDeeplinkHandler: { _, utm in
                receivedUtm = utm
            }
        )

        let url = try XCTUnwrap(URL(string: "tonkeeper://staking?utm_source=merchant&utm_campaign=autumn"))
        guard case .notOpen = handler.handlerURLOpen(url) else {
            return XCTFail("Expected navigation to be handled as a deeplink")
        }
        XCTAssertEqual(receivedUtm?.source, "merchant")
        XCTAssertEqual(receivedUtm?.campaign, "autumn")
    }

    private var parser: DeeplinkParser {
        DeeplinkParser(walletConnectDeeplinkValidator: WalletConnectDeeplinkValidatorImplementation())
    }
}
