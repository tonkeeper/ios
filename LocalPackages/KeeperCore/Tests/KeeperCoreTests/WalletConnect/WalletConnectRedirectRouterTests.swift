@testable import KeeperCore
import XCTest

final class WalletConnectRedirectRouterTests: XCTestCase {
    func testNativeRedirectURIAllowsOnlyNativeDappSource() {
        let dapp = WalletConnectDapp(
            name: "dApp",
            url: "https://example.com",
            description: "Test dApp",
            iconURL: nil,
            redirect: WalletConnectDappRedirect(
                native: "example://wc",
                universal: "https://example.com/wc"
            )
        )

        XCTAssertNil(WalletConnectRedirectRouter.nativeRedirectURI(for: dapp, source: .deeplink))
        XCTAssertNil(WalletConnectRedirectRouter.nativeRedirectURI(for: dapp, source: .dapp))
        XCTAssertNil(WalletConnectRedirectRouter.nativeRedirectURI(for: dapp, source: .browser))
        XCTAssertNil(WalletConnectRedirectRouter.nativeRedirectURI(for: dapp, source: .qr))
        XCTAssertNil(WalletConnectRedirectRouter.nativeRedirectURI(for: dapp, source: nil))
    }

    func testNativeRedirectURISkipsMissingRedirect() {
        XCTAssertNil(WalletConnectRedirectRouter.nativeRedirectURI(
            for: WalletConnectDapp(
                name: "dApp",
                url: "https://example.com",
                description: "Test dApp",
                iconURL: nil
            ),
            source: .dapp
        ))
    }

    func testNativeRedirectURITrimsWhitespace() {
        let dapp = WalletConnectDapp(
            name: "dApp",
            url: "https://example.com",
            description: "Test dApp",
            iconURL: nil,
            redirect: WalletConnectDappRedirect(
                native: "  example://wc  ",
                universal: nil
            )
        )

        XCTAssertNil(WalletConnectRedirectRouter.nativeRedirectURI(for: dapp, source: .dapp))
    }

    func testNativeRedirectURIRejectsInvalidWebAndSelfLoopURIs() {
        let invalidURIs = [
            "",
            " ",
            "not a url",
            "https://example.com/wc",
            "tonkeeper://wc",
            "tonkeeper-mob://wc",
            "wc://wc",
        ]

        for uri in invalidURIs {
            let dapp = WalletConnectDapp(
                name: "dApp",
                url: "https://example.com",
                description: "Test dApp",
                iconURL: nil,
                redirect: WalletConnectDappRedirect(
                    native: uri,
                    universal: nil
                )
            )

            XCTAssertNil(
                WalletConnectRedirectRouter.nativeRedirectURI(for: dapp, source: .dapp),
                uri
            )
        }
    }

    func testRoutingPolicyDistinguishesSources() {
        XCTAssertEqual(WalletConnectRedirectRouter.RoutingPolicy(source: .qr), .qr)
        XCTAssertEqual(WalletConnectRedirectRouter.RoutingPolicy(source: .browser), .browser)
        XCTAssertEqual(WalletConnectRedirectRouter.RoutingPolicy(source: .dapp), .deeplink)
        XCTAssertEqual(WalletConnectRedirectRouter.RoutingPolicy(source: .deeplink), .deeplink)
        XCTAssertEqual(WalletConnectRedirectRouter.RoutingPolicy(source: nil), .deeplink)
    }
}
