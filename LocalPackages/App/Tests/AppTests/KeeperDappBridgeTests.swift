@testable import App
import Foundation
@testable import KeeperCore
import TKUIKit
import TonSwift
import XCTest

final class KeeperDappBridgeTests: XCTestCase {
    func test_onlyHTTPSSubdomainsOfKeeperWalletOnTheStandardPortAreTrusted() {
        let trusted = [
            "https://trump.keeperwallet.com/",
            "https://battery.keeperwallet.com:443/refill",
            "https://a.b.keeperwallet.com",
            "https://TRUMP.KeeperWallet.com",
        ]
        let untrusted = [
            "https://keeperwallet.com",
            "https://fakekeeperwallet.com",
            "https://keeperwallet.com.example.org",
            "https://trump.keeperwallet.com.example.org",
            "http://trump.keeperwallet.com",
            "https://trump.keeperwallet.com:8443",
            "tonkeeper://trump.keeperwallet.com",
        ]

        for string in trusted {
            XCTAssertTrue(KeeperDappBridge.isTrusted(url: URL(string: string)), string)
        }
        for string in untrusted {
            XCTAssertFalse(KeeperDappBridge.isTrusted(url: URL(string: string)), string)
        }
        XCTAssertFalse(KeeperDappBridge.isTrusted(url: nil))
    }

    func test_keeperDappsOpenInASheetExceptLoyalty() throws {
        let sheet = ["https://trump.keeperwallet.com/", "https://battery.keeperwallet.com/refill"]
        let fullScreen = [
            "https://loyalty.keeperwallet.com/",
            "https://LOYALTY.KeeperWallet.com/season/1",
            "https://example.com",
        ]

        for string in sheet {
            XCTAssertTrue(try KeeperDappBridge.opensInSheet(url: XCTUnwrap(URL(string: string))), string)
        }
        for string in fullScreen {
            XCTAssertFalse(try KeeperDappBridge.opensInSheet(url: XCTUnwrap(URL(string: string))), string)
        }
    }

    func test_aKeeperDappOpensNewWindowLinksToOtherSitesInASeparateDapp() throws {
        let loyalty = KeeperDappBridge.loyaltyURL
        let explorer = try XCTUnwrap(URL(string: "https://etherscan.io/tx/0xabc"))
        let cases: [(newWindow: String, from: URL, expected: Bool)] = [
            ("https://etherscan.io/tx/0xabc", loyalty, true),
            ("http://example.com/", loyalty, true),
            ("https://trump.keeperwallet.com/", loyalty, false),
            ("https://loyalty.keeperwallet.com/shop", loyalty, false),
            ("tonkeeper://swap", loyalty, false),
            ("mailto:support@example.com", loyalty, false),
            ("https://example.com/", explorer, false),
        ]

        for testCase in cases {
            XCTAssertEqual(
                try KeeperDappBridge.opensInSeparateDapp(
                    newWindowURL: XCTUnwrap(URL(string: testCase.newWindow)),
                    from: testCase.from
                ),
                testCase.expected,
                testCase.newWindow
            )
        }
    }

    func test_onlyTheLoyaltyHostIsLoyalty() throws {
        let loyalty = ["https://loyalty.keeperwallet.com/", "https://LOYALTY.KeeperWallet.com/season/1"]
        let other = [
            "http://loyalty.keeperwallet.com/",
            "https://trump.keeperwallet.com/",
            "https://loyalty.keeperwallet.com.example.com/",
        ]

        for string in loyalty {
            XCTAssertTrue(try KeeperDappBridge.isLoyalty(url: XCTUnwrap(URL(string: string))), string)
        }
        for string in other {
            XCTAssertFalse(try KeeperDappBridge.isLoyalty(url: XCTUnwrap(URL(string: string))), string)
        }
    }

    func test_aReferralCodeOpensTheReferralsPageWithTheCode() {
        XCTAssertEqual(KeeperDappBridge.loyaltyURL(referralCode: nil).absoluteString, "https://loyalty.keeperwallet.com/")
        XCTAssertEqual(
            KeeperDappBridge.loyaltyURL(referralCode: "K7M2QX9P").absoluteString,
            "https://loyalty.keeperwallet.com/referrals?referralCode=K7M2QX9P"
        )
        XCTAssertTrue(KeeperDappBridge.isLoyalty(url: KeeperDappBridge.loyaltyURL(referralCode: "K7M2QX9P")))
    }

    func test_requestsAreReadFromTheBridgeMessageEnvelope() {
        XCTAssertEqual(
            KeeperDappBridge.parse(envelope(#"{"type":"get-data"}"#)),
            .init(queryId: "query", method: .success(.getData))
        )
        XCTAssertEqual(
            KeeperDappBridge.parse(envelope(#"{"type":"refresh-data","accessToken":"expired-token"}"#)),
            .init(queryId: "query", method: .success(.refreshData(expiredAccessToken: "expired-token")))
        )
        XCTAssertEqual(
            KeeperDappBridge.parse(envelope(#"{"type":"close"}"#)),
            .init(queryId: "query", method: .success(.close))
        )
        XCTAssertEqual(
            KeeperDappBridge.parse(envelope(#"{"type":"set-close-button","visible":false}"#)),
            .init(queryId: "query", method: .success(.setCloseButton(isVisible: false)))
        )
        XCTAssertEqual(
            KeeperDappBridge.parse(envelope(#"{"type":"set-close-button","visible":true}"#)),
            .init(queryId: "query", method: .success(.setCloseButton(isVisible: true)))
        )
        XCTAssertEqual(
            KeeperDappBridge.parse(envelope(#"{"type":"share","text":"Join me on Keeper"}"#)),
            .init(queryId: "query", method: .success(.share(text: "Join me on Keeper")))
        )
        let styles: [(String, KeeperDappBridge.HapticStyle)] = [
            ("selection", .selection), ("light", .light), ("medium", .medium), ("heavy", .heavy),
            ("success", .success), ("warning", .warning), ("error", .error),
        ]
        for (name, style) in styles {
            XCTAssertEqual(
                KeeperDappBridge.parse(envelope(#"{"type":"haptic","style":"\#(name)"}"#)),
                .init(queryId: "query", method: .success(.haptic(style))),
                name
            )
        }
    }

    func test_requestsWithAQueryIdAreAnsweredWithTheContractErrorCode() {
        let cases: [(Any, KeeperDappBridge.ErrorCode)] = [
            (envelope(#"{"type":"navigate","payload":{"screen":"wallet","params":{}}}"#), .unsupportedMethod),
            (envelope(#"{"type":"unknown"}"#), .unsupportedMethod),
            (envelope("not json"), .invalidParams),
            (envelope(#"{"payload":{}}"#), .invalidParams),
            (envelope(#"{"type":"refresh-data"}"#), .invalidParams),
            (envelope(#"{"type":"refresh-data","accessToken":""}"#), .invalidParams),
            (envelope(#"{"type":"refresh-data","payload":{"accessToken":"expired-token"}}"#), .invalidParams),
            (envelope(#"{"type":"haptic"}"#), .invalidParams),
            (envelope(#"{"type":"haptic","style":"soft"}"#), .invalidParams),
            (envelope(#"{"type":"set-close-button"}"#), .invalidParams),
            (envelope(#"{"type":"set-close-button","visible":"false"}"#), .invalidParams),
            (envelope(#"{"type":"set-close-button","visible":0}"#), .invalidParams),
            (envelope(#"{"type":"share"}"#), .invalidParams),
            (envelope(#"{"type":"share","text":""}"#), .invalidParams),
            (envelope(#"{"type":"share","text":" "}"#), .invalidParams),
            (envelope(#"{"type":"share","text":42}"#), .invalidParams),
            (envelope(#"{"type":"analytics.track"}"#), .invalidParams),
            (envelope(#"{"type":"analytics.track","event":" "}"#), .invalidParams),
            (envelope(#"{"type":"analytics.track","event":"\#(String(repeating: "e", count: 41))"}"#), .invalidParams),
            (["type": "bridge-message", "queryId": "query", "payload": ["type": "get-data"]], .invalidParams),
        ]

        for (message, code) in cases {
            XCTAssertEqual(KeeperDappBridge.parse(message), .init(queryId: "query", method: .failure(code)), "\(message)")
        }
    }

    func test_trackKeepsScalarParamsWithValidKeysAndRedactsAddresses() {
        let address = "UQBvW8Z5huBkMJYdnfAEM5JqTNkuWX3diqYENkWsIL0XggGG"
        let payload = """
        {"type":"analytics.track","event":"loyalty_quest_opened","params":{"tab":"quests","count":3,\
        "wallet":"\(address)","nested":{"a":1},"list":[1],"\(String(repeating: "k", count: 41))":"long"}}
        """

        XCTAssertEqual(
            KeeperDappBridge.parse(envelope(payload)),
            .init(queryId: "query", method: .success(.track(
                event: "loyalty_quest_opened",
                params: ["tab": "quests", "count": 3, "wallet": "<hex>"]
            )))
        )
        XCTAssertEqual(
            KeeperDappBridge.parse(envelope(#"{"type":"analytics.track","event":"loyalty_opened"}"#)),
            .init(queryId: "query", method: .success(.track(event: "loyalty_opened", params: [:])))
        )
    }

    func test_messagesWithoutAQueryIdAreIgnored() {
        let messages: [Any] = [
            #"{"type":"bridge-message","queryId":"query","payload":"{\"type\":\"get-data\"}"}"#,
            ["type": "invokeRnFunc", "queryId": "query", "payload": #"{"type":"get-data"}"#],
            ["type": "bridge-message", "payload": #"{"type":"get-data"}"#],
            ["type": "bridge-message", "queryId": "", "payload": #"{"type":"get-data"}"#],
            42,
        ]

        for message in messages {
            XCTAssertNil(KeeperDappBridge.parse(message), "expected \(message) to be ignored")
        }
    }

    func test_successResponse_carriesThePayloadAsAnObjectWithANullError() throws {
        let payload = KeeperDappBridge.getDataPayload(
            authorization: BatteryWebAuthorization(walletId: "wallet", deviceToken: "device-token", walletToken: "proof\""),
            theme: "dark",
            language: "ru",
            referralCode: nil
        )

        let object = try responseObject(queryId: "query\"\\", result: .success(payload))

        XCTAssertEqual(Set(object.keys), ["queryId", "payload", "error"])
        XCTAssertEqual(object["queryId"] as? String, "query\"\\")
        XCTAssertTrue(object["error"] is NSNull)
        XCTAssertEqual(object["payload"] as? [String: String], [
            "walletId": "wallet",
            "deviceToken": "device-token",
            "walletToken": "proof\"",
            "theme": "dark",
            "language": "ru",
        ])
    }

    func test_getDataPayload_carriesTheReferralCodeWhenThereIsOne() {
        let payload = KeeperDappBridge.getDataPayload(
            authorization: BatteryWebAuthorization(walletId: "wallet", deviceToken: "device-token", walletToken: "proof"),
            theme: "dark",
            language: "ru",
            referralCode: "Ab-9_x"
        )

        XCTAssertEqual(payload["referralCode"], "Ab-9_x")
        XCTAssertEqual(payload["walletId"], "wallet")
    }

    func test_refreshDataPayload_carriesOnlyTheCredentials() {
        let payload = KeeperDappBridge.refreshDataPayload(
            authorization: BatteryWebAuthorization(walletId: "wallet", deviceToken: "device-token", walletToken: "proof")
        )

        XCTAssertEqual(payload, ["walletId": "wallet", "deviceToken": "device-token", "walletToken": "proof"])
    }

    func test_errorResponse_carriesANullPayloadAndTheCodeWithAMessage() throws {
        let object = try responseObject(queryId: "query", result: .failure(.unauthorized))

        XCTAssertEqual(object["queryId"] as? String, "query")
        XCTAssertTrue(object["payload"] is NSNull)
        XCTAssertEqual(object["error"] as? [String: String], ["code": "UNAUTHORIZED", "message": "Authorization failed"])
    }

    func test_themeIsTheKeeperThemeNameWithSystemResolvedToLightOrDark() {
        XCTAssertEqual(KeeperDappBridge.theme(for: .deepBlue), "deepBlue")
        XCTAssertEqual(KeeperDappBridge.theme(for: .dark), "dark")
        XCTAssertEqual(KeeperDappBridge.theme(for: .light), "light")
        XCTAssertTrue(["light", "dark"].contains(KeeperDappBridge.theme(for: .system)))
    }

    func test_sessionEndsWhenTheWalletStopsBeingActiveOrIsRemoved() {
        let wallet = makeWallet(id: "wallet")
        let other = makeWallet(id: "other")

        XCTAssertTrue(KeeperDappBridge.endsSession(of: wallet, on: .didChangeActiveWallet(from: wallet, to: other)))
        XCTAssertTrue(KeeperDappBridge.endsSession(of: wallet, on: .didDeleteWallet(wallet: wallet)))
        XCTAssertTrue(KeeperDappBridge.endsSession(of: wallet, on: .didDeleteAll))
        XCTAssertFalse(KeeperDappBridge.endsSession(of: wallet, on: .didChangeActiveWallet(from: other, to: wallet)))
        XCTAssertFalse(KeeperDappBridge.endsSession(of: wallet, on: .didDeleteWallet(wallet: other)))
        XCTAssertFalse(KeeperDappBridge.endsSession(of: wallet, on: .didUpdateWalletMetaData(wallet: wallet)))
    }
}

private extension KeeperDappBridgeTests {
    func envelope(_ payload: String) -> [String: Any] {
        ["type": "bridge-message", "queryId": "query", "payload": payload]
    }

    func responseObject(
        queryId: String,
        result: Result<[String: String], KeeperDappBridge.ErrorCode>
    ) throws -> [String: Any] {
        let response = try XCTUnwrap(KeeperDappBridge.response(queryId: queryId, result: result))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(response.utf8)) as? [String: Any])
    }

    func makeWallet(id: String) -> Wallet {
        Wallet(
            id: id,
            identity: WalletIdentity(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)),
            metaData: WalletMetaData(label: "Test wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings()
        )
    }
}
