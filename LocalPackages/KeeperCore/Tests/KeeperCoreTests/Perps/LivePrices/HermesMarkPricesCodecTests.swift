@testable import KeeperCore
import XCTest

final class HermesMarkPricesCodecTests: XCTestCase {
    func test_subscribeRequest_encodesTickersAndCooldown() throws {
        let data = try HermesMarkPricesCodec.subscribeRequest(
            tickers: ["BTC/USD", "TON/USD"],
            cooldown: "PT2S",
            reqid: 7
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["channel"] as? String, "subscribeMarkPrices")
        let message = try XCTUnwrap(object["message"] as? [String: Any])
        XCTAssertEqual(message["name"] as? String, "subscribeMarkPricesRequest")
        XCTAssertEqual(message["reqid"] as? Int64, 7)
        let payload = try XCTUnwrap(message["payload"] as? [String: Any])
        XCTAssertEqual(payload["tickers"] as? [String], ["BTC/USD", "TON/USD"])
        XCTAssertEqual(payload["cooldown"] as? String, "PT2S")
    }

    func test_event_decodesMarkPricesSnapshot() {
        let frame = """
        {"channel":"markPrices","message":{"name":"markPricesMessage","payload":{
        "timestamp":1787838181001,
        "markPrices":[{"ticker":"BTC/USD","markPrice":"79237.5"},{"ticker":"XAU/USD","markPrice":"4585.21"}]}}}
        """
        let event = HermesMarkPricesCodec.event(from: Data(frame.utf8))
        XCTAssertEqual(event, .prices([
            HermesTickerPrice(ticker: "BTC/USD", price: "79237.5"),
            HermesTickerPrice(ticker: "XAU/USD", price: "4585.21"),
        ]))
    }

    func test_event_decodesSubscribeResponse() {
        let frame = """
        {"channel":"subscribeMarkPrices","message":{"name":"subscribeMarkPricesResponse","reqid":2}}
        """
        XCTAssertEqual(HermesMarkPricesCodec.event(from: Data(frame.utf8)), .subscribed)
    }

    func test_event_alreadySubscribed_countsAsSubscribed() {
        let frame = """
        {"channel":"subscribeMarkPrices","message":{"name":"errorResponse","reqid":3,
        "payload":{"code":"already.subscribed","description":"Already subscribed"}}}
        """
        XCTAssertEqual(HermesMarkPricesCodec.event(from: Data(frame.utf8)), .subscribed)
    }

    func test_event_unauthorized_isPermanentRejection() {
        let frame = """
        {"channel":"subscribeMarkPrices","message":{"name":"errorResponse","reqid":1,
        "payload":{"code":"unauthorized","description":"Unauthorized","fatal":false}}}
        """
        XCTAssertEqual(HermesMarkPricesCodec.event(from: Data(frame.utf8)), .rejected)
    }

    func test_event_invalidRequest_declinesTheSetOnly() {
        let frame = """
        {"channel":"subscribeMarkPrices","message":{"name":"errorResponse","reqid":4,
        "payload":{"code":"invalid.request","description":"Unsupported ticker","fatal":false}}}
        """
        XCTAssertEqual(HermesMarkPricesCodec.event(from: Data(frame.utf8)), .declined)
    }

    func test_event_notFound_declinesTheSetOnly() {
        let frame = """
        {"channel":"subscribeMarkPrices","message":{"name":"errorResponse","reqid":5,
        "payload":{"code":"not.found","description":"Not found"}}}
        """
        XCTAssertEqual(HermesMarkPricesCodec.event(from: Data(frame.utf8)), .declined)
    }

    func test_event_unknownSubscribeError_isRetryable() {
        let frame = """
        {"channel":"subscribeMarkPrices","message":{"name":"errorResponse","reqid":1,
        "payload":{"code":"internal.error","description":"boom"}}}
        """
        XCTAssertEqual(HermesMarkPricesCodec.event(from: Data(frame.utf8)), .retryableFailure)
    }

    func test_event_foreignChannelsAndGarbage_areIgnored() {
        let candleFrame = """
        {"channel":"candles","message":{"name":"candlesFeedMessage","payload":{"feedId":"BTC/USD/1m"}}}
        """
        XCTAssertEqual(HermesMarkPricesCodec.event(from: Data(candleFrame.utf8)), .ignored)
        XCTAssertEqual(HermesMarkPricesCodec.event(from: Data("not json".utf8)), .ignored)
    }
}
