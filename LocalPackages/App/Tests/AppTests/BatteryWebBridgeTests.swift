@testable import App
import Foundation
import KeeperCore
import XCTest

final class BatteryWebBridgeTests: XCTestCase {
    func test_getData_parsesWithoutExpiredToken() {
        let request = BatteryWebBridge.parse(#"{"type":"get-data","queryId":"query-1"}"#)

        XCTAssertEqual(request, .init(queryId: "query-1", method: .getData, expiredAccessToken: nil))
    }

    func test_refreshData_carriesExpiredToken() {
        let request = BatteryWebBridge.parse(
            #"{"type":"refresh-data","queryId":"query-2","accessToken":"expired-token"}"#
        )

        XCTAssertEqual(request, .init(queryId: "query-2", method: .refreshData, expiredAccessToken: "expired-token"))
    }

    func test_malformedAndUnrelatedMessages_areIgnored() {
        let messages: [Any] = [
            "not json",
            "[]",
            #"{"type":"invokeRnFunc","queryId":"query"}"#,
            #"{"type":"get-data"}"#,
            #"{"type":"get-data","queryId":123}"#,
            #"{"type":"refresh-data","queryId":"query"}"#,
            #"{"type":"refresh-data","queryId":"query","accessToken":""}"#,
            #"{"type":"refresh-data","queryId":"query","accessToken":null}"#,
            #"{"type":"refresh-data","queryId":"query","accessToken":123}"#,
            ["type": "get-data", "queryId": "query"],
            42,
        ]

        for message in messages {
            XCTAssertNil(BatteryWebBridge.parse(message), "expected \(message) to be ignored")
        }
    }

    func test_response_correlatesQueryIdAndEncodesPayloadAsString() throws {
        let response = try XCTUnwrap(BatteryWebBridge.response(
            queryId: "query-1",
            authorization: BatteryWebAuthorization(walletId: "wallet", deviceToken: "current-token", walletToken: "proof")
        ))

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(response.utf8)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["queryId", "payload"])
        XCTAssertEqual(object["queryId"] as? String, "query-1")
        let payloadString = try XCTUnwrap(object["payload"] as? String)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(payloadString.utf8)) as? [String: String])
        XCTAssertEqual(payload, ["walletId": "wallet", "deviceToken": "current-token", "walletToken": "proof"])
    }

    func test_response_escapesQueryIdAndPayloadStrings() throws {
        let proof = "proof\"\\\n"
        let queryId = "query\"\\\n"
        let response = try XCTUnwrap(BatteryWebBridge.response(
            queryId: queryId,
            authorization: BatteryWebAuthorization(walletId: "", deviceToken: "", walletToken: proof)
        ))

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(response.utf8)) as? [String: Any])
        XCTAssertEqual(object["queryId"] as? String, queryId)
        let payloadString = try XCTUnwrap(object["payload"] as? String)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(payloadString.utf8)) as? [String: String])
        XCTAssertEqual(payload["walletToken"], proof)
        XCTAssertEqual(payload["deviceToken"], "")
    }

    func test_trustedOrigin_requiresSameHttpsHostAndPort() throws {
        let start = try XCTUnwrap(URL(string: "https://bat.tonkeeper.com/?token=abc"))

        XCTAssertTrue(BatteryWebBridge.isTrustedOrigin(pageURL: URL(string: "https://bat.tonkeeper.com/history"), startURL: start))
        XCTAssertTrue(BatteryWebBridge.isTrustedOrigin(pageURL: URL(string: "https://BAT.tonkeeper.com/"), startURL: start))
        XCTAssertTrue(BatteryWebBridge.isTrustedOrigin(pageURL: URL(string: "https://bat.tonkeeper.com:443/"), startURL: start))

        XCTAssertFalse(BatteryWebBridge.isTrustedOrigin(pageURL: URL(string: "http://bat.tonkeeper.com/"), startURL: start))
        XCTAssertFalse(BatteryWebBridge.isTrustedOrigin(pageURL: URL(string: "https://bat.tonkeeper.com:8443/"), startURL: start))
        XCTAssertFalse(BatteryWebBridge.isTrustedOrigin(pageURL: URL(string: "https://evil.example.com/"), startURL: start))
        XCTAssertFalse(BatteryWebBridge.isTrustedOrigin(pageURL: nil, startURL: start))
        XCTAssertFalse(try BatteryWebBridge.isTrustedOrigin(
            pageURL: URL(string: "http://bat.tonkeeper.com/"),
            startURL: XCTUnwrap(URL(string: "http://bat.tonkeeper.com/"))
        ))
    }
}
