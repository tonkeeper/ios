@testable import KeeperCore
import TKKandelabrAPI
import XCTest

final class PerpsChartHistorySourceTests: XCTestCase {
    func test_latest_requestsWireCountForTwelveHourTimeframe() async {
        let kandelabr = HistoryKandelabrFake(.response(makeResponse()))
        let source = PerpsChartHistorySource(kandelabr: kandelabr, timeframe: .h12)

        guard case .response = await source.latest(ticker: "ETH/USD", count: 10) else {
            return XCTFail("Expected response")
        }

        let request = await kandelabr.recordedRequest
        XCTAssertEqual(request?.ticker, "ETH/USD")
        XCTAssertEqual(request?.resolution, "4h")
        XCTAssertEqual(request?.limit, 30)
        XCTAssertNil(request?.endTs)
    }

    func test_latest_classifiesRejectedAndUnavailableFailures() async {
        for error in [KandelabrAPIError.badRequest, .notFound] {
            let source = PerpsChartHistorySource(
                kandelabr: HistoryKandelabrFake(.failure(error)),
                timeframe: .h1
            )
            guard case .rejected = await source.latest(ticker: "ETH/USD", count: 10) else {
                return XCTFail("Expected rejected result for \(error)")
            }
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
        let kandelabr = HistoryKandelabrFake(.response(makeResponse()))
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
        let ticker: String
        let resolution: String
        let limit: Int32?
        let endTs: Int64?
    }

    enum Stub: Sendable {
        case response(TKKandelabrAPI.Components.Schemas.GetCandlesResponse)
        case failure(KandelabrAPIError)
    }

    private let stub: Stub
    private(set) var recordedRequest: Request?

    init(_ stub: Stub) {
        self.stub = stub
    }

    func candles(
        ticker: String,
        resolution: String,
        limit: Int32?,
        startTs _: Int64?,
        endTs: Int64?
    ) async throws(KandelabrAPIError) -> TKKandelabrAPI.Components.Schemas.GetCandlesResponse {
        recordedRequest = Request(
            ticker: ticker,
            resolution: resolution,
            limit: limit,
            endTs: endTs
        )
        switch stub {
        case let .response(response):
            return response
        case let .failure(error):
            throw error
        }
    }
}

private func makeResponse() -> TKKandelabrAPI.Components.Schemas.GetCandlesResponse {
    .init(
        ticker: "ETH/USD",
        resolution: "4h",
        start_ts: 1_700_000_000_000,
        candles: []
    )
}
