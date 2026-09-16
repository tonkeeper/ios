@testable import App
import KeeperCore
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
        XCTAssertEqual(flow.phase, .composing(marketId: 1))

        flow.close()
        XCTAssertEqual(flow.phase, .idle)
        XCTAssertTrue(flow.begin(marketId: 2))
    }

    func test_beginSubmitting_requiresComposingTheSameMarket() {
        let flow = PerpsOpenPositionFlow()
        XCTAssertFalse(flow.beginSubmitting(trade))

        _ = flow.begin(marketId: 2)
        XCTAssertFalse(flow.beginSubmitting(trade))
        XCTAssertNil(flow.activeTrade)

        flow.close()
        _ = flow.begin(marketId: 1)
        XCTAssertTrue(flow.beginSubmitting(trade))
        XCTAssertEqual(flow.activeTrade, trade)
        XCTAssertFalse(flow.beginSubmitting(trade))
    }

    func test_submitting_blocksBeginAndClose_untilFinished() {
        let flow = PerpsOpenPositionFlow()
        _ = flow.begin(marketId: 1)
        _ = flow.beginSubmitting(trade)

        flow.close()
        XCTAssertEqual(flow.phase, .submitting(trade))
        XCTAssertFalse(flow.begin(marketId: 1))

        flow.finishSubmitting()
        XCTAssertEqual(flow.phase, .idle)
        XCTAssertNil(flow.activeTrade)
        XCTAssertTrue(flow.begin(marketId: 1))
    }
}
