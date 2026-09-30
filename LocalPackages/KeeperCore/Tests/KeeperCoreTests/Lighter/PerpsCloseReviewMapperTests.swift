import ChainKit
@testable import KeeperCore
import XCTest

final class PerpsCloseReviewMapperTests: XCTestCase {
    private let scale = PerpsScale(priceDecimals: 4, baseDecimals: 5, quoteDecimals: 9)

    func testPnlPercentIsReturnOnTheMarginComingBack() throws {
        let mapped = PerpsPlannerMapping.closeReview(
            makeReview(returnedMarginQuote: 50_000_000_000, realizedPnlQuote: 5_000_000_000),
            symbol: "ETH",
            leverage: 5
        )

        XCTAssertEqual(mapped.marginUsd, 50, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(mapped.estimatedPnlUsd), 5, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(mapped.estimatedPnlPercent), 10, accuracy: 1e-9)
    }

    func testPartialFillReportsWhatTheBookCanExecute() {
        let mapped = PerpsPlannerMapping.closeReview(
            makeReview(closingBaseAmount: 200_000, estimatedFillBaseAmount: 150_000),
            symbol: "ETH",
            leverage: nil
        )

        XCTAssertEqual(mapped.baseSize, 1.5, accuracy: 1e-9)
    }
}

private extension PerpsCloseReviewMapperTests {
    func makeReview(
        closingBaseAmount: Int64 = 100_000,
        estimatedFillBaseAmount: Int64 = 100_000,
        returnedMarginQuote: Int64 = 50_000_000_000,
        realizedPnlQuote: Int64 = 0
    ) -> PerpetualReview.Close {
        PerpetualReview.Close(
            side: PerpsSide.long_,
            scale: scale,
            fullExit: true,
            closingBaseAmount: closingBaseAmount,
            estimatedFillBaseAmount: estimatedFillBaseAmount,
            remainingBaseAmount: closingBaseAmount - estimatedFillBaseAmount,
            notionalQuote: 300_000_000_000,
            referencePrice: 30_000_000,
            estimatedExitPrice: 30_000_000,
            estimatedFeeQuote: 1_000_000_000,
            estimatedRealizedPnlQuote: realizedPnlQuote,
            estimatedReceiveQuote: returnedMarginQuote + realizedPnlQuote - 1_000_000_000,
            estimatedReturnedMarginQuote: returnedMarginQuote,
            priceBound: 29_000_000,
            maxNotionalQuote: 300_000_000_000,
            maxFeeQuote: 1_000_000_000,
            liquidationPrice: nil,
            liquidationUnavailableReason: nil,
            isImmediateRisk: false
        )
    }
}
