import ChainKit
@testable import KeeperCore
import XCTest

final class PerpsOpenReviewMapperTests: XCTestCase {
    func testMarginIsTheCollateralThePlannerAllocatesNotTheBudget() {
        let mapped = PerpsPlannerMapping.openReview(makeReview(kind: PerpsOrderKind.market), symbol: "BTC", feePpm: 950)

        XCTAssertEqual(mapped.marginUsd, 4.899714, accuracy: 1e-9)
        XCTAssertEqual(mapped.estimatedFeeUsd ?? 0, 0.01323, accuracy: 1e-9)
        XCTAssertEqual(mapped.feeRatePercent ?? 0, 0.095, accuracy: 1e-12)
    }

    func testLimitMarginIsWhatTheVenueReservesForTheOrder() {
        let mapped = PerpsPlannerMapping.openReview(makeReview(kind: PerpsOrderKind.limit), symbol: "BTC", feePpm: 950)

        XCTAssertEqual(mapped.marginUsd, 14.699142 * 0.3333, accuracy: 1e-9)
    }
}

private extension PerpsOpenReviewMapperTests {
    func makeReview(kind: PerpsOrderKind) -> PerpetualReview.Open {
        PerpetualReview.Open(
            side: PerpsSide.long_,
            kind: kind,
            scale: PerpsScale(priceDecimals: 1, baseDecimals: 5, quoteDecimals: 6),
            marginBudgetQuote: 5_000_000,
            initialMarginBps: 3333,
            baseAmount: 18,
            notionalQuote: 14_699_142,
            referencePrice: 816_619,
            estimatedEntryPrice: 816_619,
            estimatedFeeQuote: 13230,
            estimatedCollateralQuote: 4_899_714,
            priceBoundOrLimit: 820_700,
            maxNotionalQuote: 14_772_600,
            maxFeeQuote: 13296,
            takeProfitTrigger: nil,
            stopLossTrigger: nil,
            liquidationPrice: nil,
            liquidationUnavailableReason: nil,
            isImmediateRisk: false
        )
    }
}
