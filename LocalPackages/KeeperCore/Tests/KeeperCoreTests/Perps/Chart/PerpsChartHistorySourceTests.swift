@testable import KeeperCore
import TKKandelabrAPI
import XCTest

final class PerpsChartHistorySourceTests: XCTestCase {
    func test_latest_requestsWireCountForTwelveHourTimeframe() async {
        let kandelabr = HistoryKandelabrFake(.responses([makeResponse()]))
        let source = PerpsChartHistorySource(kandelabr: kandelabr, timeframe: .h12)

        guard case .response = await source.latest(ticker: "ETH/USD", count: 10) else {
            return XCTFail("Expected response")
        }

        let request = await kandelabr.recordedRequest
        XCTAssertEqual(request?.tickers, ["ETH/USD", "ETH/USD/PERP_TRADE"])
        XCTAssertEqual(request?.resolution, "4h")
        XCTAssertEqual(request?.limit, 30)
        XCTAssertNil(request?.endTs)
    }

    func test_latest_takesVolumesFromNonEmptyTradeCandlesByTimestamp() async {
        let hour: Int64 = 3_600_000
        let prices = makeResponse(
            resolution: "1h",
            candles: [.init(c: "1", v: "0"), .init(c: "2", v: "0"), .init(c: "3", v: "0")]
        )
        let volumes = makeResponse(
            ticker: "ETH/USD/PERP_TRADE",
            resolution: "1h",
            startTs: 1_700_000_000_000 + hour,
            candles: [.init(c: "2.1", v: "5"), .init(c: "3.1", v: "0", empty: true)]
        )
        let source = PerpsChartHistorySource(
            kandelabr: HistoryKandelabrFake(.responses([prices, volumes])),
            timeframe: .h1
        )

        guard case let .response(batch) = await source.latest(ticker: "ETH/USD", count: 3) else {
            return XCTFail("Expected response")
        }
        XCTAssertEqual(batch.ticker, "ETH/USD")
        XCTAssertEqual(batch.candles.map(\.c), ["1", "2", "3"])
        XCTAssertEqual(batch.candles.map(\.v), [nil, "5", nil])
    }

    func test_latest_classifiesRejectedAndUnavailableFailures() async {
        let rejecting = PerpsChartHistorySource(
            kandelabr: HistoryKandelabrFake(.failure(.badRequest)),
            timeframe: .h1
        )
        guard case .rejected = await rejecting.latest(ticker: "ETH/USD", count: 10) else {
            return XCTFail("Expected rejected result")
        }

        let source = PerpsChartHistorySource(
            kandelabr: HistoryKandelabrFake(.failure(.badStatus(500))),
            timeframe: .h1
        )
        guard case .unavailable = await source.latest(ticker: "ETH/USD", count: 10) else {
            return XCTFail("Expected unavailable result")
        }
    }

    func test_older_forwardsBoundaryAndWireCount() async {
        let boundary: Int64 = 1_700_000_000_000
        let kandelabr = HistoryKandelabrFake(.responses([makeResponse()]))
        let source = PerpsChartHistorySource(kandelabr: kandelabr, timeframe: .h12)

        guard case .response = await source.older(ticker: "ETH/USD", before: boundary, count: 20) else {
            return XCTFail("Expected response")
        }
        let request = await kandelabr.recordedRequest
        XCTAssertEqual(request?.limit, 60)
        XCTAssertEqual(request?.endTs, boundary)
    }
}

private actor HistoryKandelabrFake: KandelabrAPI {
    struct Request: Sendable {
        let tickers: [String]
        let resolution: String
        let limit: Int32?
        let endTs: Int64?
    }

    enum Stub: Sendable {
        case responses([TKKandelabrAPI.Components.Schemas.GetCandlesResponse])
        case failure(KandelabrAPIError)
    }

    private let stub: Stub
    private(set) var recordedRequest: Request?

    init(_ stub: Stub) {
        self.stub = stub
    }

    func candles(
        tickers: [String],
        resolution: String,
        limit: Int32?,
        endTs: Int64?
    ) async throws(KandelabrAPIError) -> [TKKandelabrAPI.Components.Schemas.GetCandlesResponse] {
        recordedRequest = Request(
            tickers: tickers,
            resolution: resolution,
            limit: limit,
            endTs: endTs
        )
        switch stub {
        case let .responses(responses):
            return responses
        case let .failure(error):
            throw error
        }
    }
}

private func makeResponse(
    ticker: String = "ETH/USD",
    resolution: String = "4h",
    startTs: Int64 = 1_700_000_000_000,
    candles: [TKKandelabrAPI.Components.Schemas.Candle] = []
) -> TKKandelabrAPI.Components.Schemas.GetCandlesResponse {
    .init(
        ticker: ticker,
        resolution: resolution,
        start_ts: startTs,
        candles: candles
    )
}
