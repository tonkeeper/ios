@testable import KeeperCore
import XCTest

final class HermesCandleCodecTests: XCTestCase {
    func test_request_encodesChannelNameReqidAndPayload() throws {
        let data = try HermesCandleCodec.request(
            channel: HermesChannel.subscribe,
            name: HermesMessageName.subscribe,
            reqid: 1,
            payload: ["feedId": "BTC/USD/1m"]
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["channel"] as? String, "subscribeCandleFeed")
        let message = try XCTUnwrap(json["message"] as? [String: Any])
        XCTAssertEqual(message["name"] as? String, "subscribeCandleFeedRequest")
        XCTAssertEqual((message["reqid"] as? NSNumber)?.int64Value, 1)
        let payload = try XCTUnwrap(message["payload"] as? [String: String])
        XCTAssertEqual(payload["feedId"], "BTC/USD/1m")
    }

    func test_request_omitsPayloadKeyWhenNil() throws {
        let data = try HermesCandleCodec.request(
            channel: HermesChannel.ping,
            name: HermesMessageName.ping,
            reqid: 2
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let message = try XCTUnwrap(json["message"] as? [String: Any])
        XCTAssertNil(message["payload"])
    }

    func test_event_decodesCandlesPush() throws {
        let frame = """
        {"channel":"candles","message":{"name":"candlesFeedMessage","payload":{"data":{"ticker":"BTC/USD","resolution":"1m","start_ts":1700000000000,"candles":[{"o":"1","h":"2","l":"0.5","c":"1.5","v":"10"}]}}}}
        """
        let event = try HermesCandleCodec.event(from: XCTUnwrap(frame.data(using: .utf8)))
        guard case let .candles(batch) = event else {
            return XCTFail("expected candles, got \(event)")
        }
        XCTAssertEqual(batch.ticker, "BTC/USD")
        XCTAssertEqual(batch.resolution, "1m")
        XCTAssertEqual(batch.start_ts, 1_700_000_000_000)
        XCTAssertEqual(batch.candles.count, 1)
        XCTAssertEqual(batch.candles.first?.c, "1.5")
    }

    func test_event_mapsSuccessfulSubscriptionVariants() throws {
        let cases: [(String, HermesCandleEvent)] = [
            (#"{"channel":"subscribeCandleFeed","message":{"name":"subscribeCandleFeedResponse","reqid":7}}"#, .subscribed(requestId: 7)),
            (#"{"channel":"subscribeCandleFeed","message":{"name":"errorResponse","reqid":8,"payload":{"code":"already.subscribed"}}}"#, .subscribed(requestId: 8)),
        ]
        for (frame, expected) in cases {
            XCTAssertEqual(
                try HermesCandleCodec.event(from: XCTUnwrap(frame.data(using: .utf8))),
                expected
            )
        }
    }

    func test_event_mapsPermanentSubscribeErrorsToRejected() throws {
        let frames = [
            #"{"channel":"subscribeCandleFeed","message":{"name":"errorResponse","payload":{"code":"not.found","description":"unknown feed"}}}"#,
            #"{"channel":"subscribeCandleFeed","message":{"name":"errorMessage","payload":{"code":"invalid.request"}}}"#,
            #"{"channel":"subscribeCandleFeed","message":{"name":"errorResponse","payload":{"code":"unauthorized","description":"Unauthorized"}}}"#,
        ]
        for frame in frames {
            XCTAssertEqual(
                try HermesCandleCodec.event(from: XCTUnwrap(frame.data(using: .utf8))),
                .rejected
            )
        }
    }

    func test_event_transientSubscribeErrorRequestsReconnect() throws {
        let frame = """
        {"channel":"subscribeCandleFeed","message":{"name":"errorResponse","payload":{"code":"unavailable"}}}
        """
        XCTAssertEqual(
            try HermesCandleCodec.event(from: XCTUnwrap(frame.data(using: .utf8))),
            .retryableFailure
        )
    }

    func test_webSocketURL_rewritesHTTPVariantsOntoHermesPath() throws {
        let cases = [
            ("https://tonapi.io", "wss://tonapi.io/hermes/public-api/v1/ws"),
            ("http://localhost:8080", "ws://localhost:8080/hermes/public-api/v1/ws"),
        ]
        for (source, expected) in cases {
            let url = try XCTUnwrap(
                HermesEndpoint.webSocketURL(from: XCTUnwrap(URL(string: source)))
            )
            XCTAssertEqual(url.absoluteString, expected)
        }
    }
}
