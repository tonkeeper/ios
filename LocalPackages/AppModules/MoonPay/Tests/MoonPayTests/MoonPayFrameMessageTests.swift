@testable import MoonPay
import XCTest

final class MoonPayFrameMessageTests: XCTestCase {
    func testRoundTrip() throws {
        let message = MoonPayFrameMessage(
            kind: "complete",
            channelId: "ch_1",
            payload: .object(["status": .string("active"), "mismatch": .bool(true), "count": .number(2)])
        )
        let decoded = try MoonPayFrameMessage.decode(jsonString: message.encodedJSONString())
        XCTAssertEqual(decoded, message)
        XCTAssertEqual(decoded.version, 2)
        XCTAssertEqual(decoded.channelId, "ch_1")
    }

    func testDecodesDocumentedHandshake() throws {
        let message = try MoonPayFrameMessage.decode(jsonString: #"{"version":2,"meta":{"channelId":"ch_1"},"kind":"handshake"}"#)
        XCTAssertEqual(message.kind, "handshake")
        XCTAssertNil(message.payload)
    }

    func testMissingVersionDefaultsToProtocolVersion() throws {
        let message = try MoonPayFrameMessage.decode(jsonString: #"{"meta":{"channelId":"ch_1"},"kind":"ready"}"#)
        XCTAssertEqual(message.version, MoonPayFrameMessage.protocolVersion)
    }

    func testEncodedMessageOmitsNilPayload() throws {
        let json = try MoonPayFrameMessage(kind: "ack", channelId: "ch_1").encodedJSONString()
        XCTAssertEqual(json, #"{"kind":"ack","meta":{"channelId":"ch_1"},"version":2}"#)
    }

    func testPostMessageStatementEmbedsJSONAsStringLiteral() throws {
        let statement = try MoonPayFrameCommand.ack.message(channelId: "ch_1").javaScriptPostMessageStatement()
        XCTAssertEqual(
            statement,
            #"window.postMessage("{\"kind\":\"ack\",\"meta\":{\"channelId\":\"ch_1\"},\"version\":2}", '*');"#
        )
    }

    func testJavaScriptStringLiteralEscaping() {
        let literal = MoonPayFrameMessage.javaScriptStringLiteral("a\"b\\c\n\u{2028}d\u{01}")
        let expected = #""a\"b\\c\n"# + "\\" + "u2028" + #"d\u0001""#
        XCTAssertEqual(literal, expected)
    }

    func testSetQuoteCommandPayload() {
        let message = MoonPayFrameCommand.setQuote(signature: "sig").message(channelId: "ch_1")
        XCTAssertEqual(message.kind, "setQuote")
        XCTAssertEqual(message.payload, .object(["quote": .object(["signature": .string("sig")])]))
    }

    // MARK: - Bridge

    private let bridge = MoonPayFrameBridge(channelId: "ch_1", environment: .production)

    func testBridgeDecodesStringBody() {
        let inbound = bridge.receive(body: #"{"version":2,"meta":{"channelId":"ch_1"},"kind":"ready"}"#)
        XCTAssertEqual(inbound, .event(.ready))
    }

    func testBridgeDecodesObjectBody() {
        let body: [String: Any] = ["version": 2, "meta": ["channelId": "ch_1"], "kind": "buttonPressed"]
        XCTAssertEqual(bridge.receive(body: body), .event(.buttonPressed))
    }

    func testBridgeIgnoresForeignChannel() {
        let inbound = bridge.receive(body: #"{"version":2,"meta":{"channelId":"other"},"kind":"ready"}"#)
        XCTAssertEqual(inbound, .foreignChannel("other"))
    }

    func testBridgeRejectsUnsupportedBodyAndBadJSON() {
        guard case .malformed = bridge.receive(body: 42) else {
            return XCTFail("expected malformed for a number body")
        }
        guard case .malformed = bridge.receive(body: "{not json") else {
            return XCTFail("expected malformed for invalid JSON")
        }
        guard case .malformed = bridge.receive(body: #"{"version":2,"meta":{"channelId":"ch_1"},"kind":"challenge","payload":{}}"#) else {
            return XCTFail("expected malformed for a challenge without url")
        }
    }

    func testTrustedOrigin() {
        XCTAssertTrue(bridge.isTrustedOrigin(scheme: "https", host: "platform.moonpay.com"))
        XCTAssertTrue(bridge.isTrustedOrigin(scheme: "HTTPS", host: "Platform.MoonPay.com"))
        XCTAssertFalse(bridge.isTrustedOrigin(scheme: "http", host: "platform.moonpay.com"))
        XCTAssertFalse(bridge.isTrustedOrigin(scheme: "https", host: "evil.example"))
        XCTAssertFalse(bridge.isTrustedOrigin(scheme: "https", host: "platform.moonpay.com.evil.example"))
        XCTAssertFalse(bridge.isTrustedOrigin(scheme: nil, host: "platform.moonpay.com"))
        XCTAssertFalse(bridge.isTrustedOrigin(scheme: "https", host: nil))
        XCTAssertFalse(MoonPayFrameBridge(channelId: "c", trustedHost: "").isTrustedOrigin(scheme: "https", host: ""))
    }

    func testUserScriptTargetsMessageHandler() {
        XCTAssertTrue(MoonPayFrameBridge.userScriptSource.contains("window.webkit.messageHandlers.\(MoonPayFrameBridge.messageHandlerName).postMessage"))
        XCTAssertTrue(MoonPayFrameBridge.userScriptSource.contains("window.MoonPayBridge"))
    }
}
