@testable import Perps
import PerpsModels
import XCTest

@MainActor
final class PerpsOpenPositionFlowTests: XCTestCase {
    private let trade = PerpsOpeningDescriptor(
        marketId: 1, symbol: "BTC", side: .long, marginUsd: 20, leverage: 27, isLimit: false
    )

    func test_begin_rejectsWhileComposing_untilClosed() {
        let flow = PerpsOpenPositionFlow()

        XCTAssertTrue(flow.begin(marketId: 1))
        XCTAssertFalse(flow.begin(marketId: 1))
        XCTAssertFalse(flow.begin(marketId: 2))
        XCTAssertEqual(flow.composingMarketId, 1)

        flow.close()
        XCTAssertNil(flow.composingMarketId)
        XCTAssertTrue(flow.begin(marketId: 2))
    }

    func test_beginSubmitting_requiresComposingTheSameMarket() {
        let flow = PerpsOpenPositionFlow()
        XCTAssertFalse(flow.beginSubmitting(trade))

        _ = flow.begin(marketId: 2)
        XCTAssertFalse(flow.beginSubmitting(trade))
        XCTAssertNil(flow.activeTrade(marketId: 1))

        flow.close()
        _ = flow.begin(marketId: 1)
        XCTAssertTrue(flow.beginSubmitting(trade))
        XCTAssertEqual(flow.activeTrade(marketId: 1), trade)
        XCTAssertFalse(flow.beginSubmitting(trade))
    }

    func test_cancelSubmitting_returnsToComposingTheSameMarket() {
        let flow = PerpsOpenPositionFlow()
        XCTAssertTrue(flow.begin(marketId: 1))
        XCTAssertTrue(flow.beginSubmitting(trade))

        flow.cancelSubmitting(marketId: 1)

        XCTAssertEqual(flow.composingMarketId, 1)
        XCTAssertNil(flow.activeTrade(marketId: 1))
        XCTAssertTrue(flow.beginSubmitting(trade))
    }

    func test_submitting_holdsOnlyItsOwnMarket_untilFinished() {
        let flow = PerpsOpenPositionFlow()
        _ = flow.begin(marketId: 1)
        _ = flow.beginSubmitting(trade)

        XCTAssertFalse(flow.begin(marketId: 1))
        XCTAssertTrue(flow.begin(marketId: 2))
        flow.close()

        flow.finishSubmitting(marketId: 1)
        XCTAssertNil(flow.activeTrade(marketId: 1))
        XCTAssertTrue(flow.begin(marketId: 1))
    }
}
