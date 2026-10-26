import ChainKit
import Foundation
@testable import KeeperCore
import XCTest

final class PerpsTradingMappersTests: XCTestCase {
    func testLiquidationReasonMapperCoversAllCases() {
        XCTAssertEqual(PerpsLiquidationReasonMapper.map(PerpsLiquidationUnavailable.flatposition), .flatPosition)
        XCTAssertEqual(PerpsLiquidationReasonMapper.map(PerpsLiquidationUnavailable.missingmark), .missingMark)
        XCTAssertEqual(PerpsLiquidationReasonMapper.map(PerpsLiquidationUnavailable.missingcollateral), .missingCollateral)
        XCTAssertEqual(
            PerpsLiquidationReasonMapper.map(PerpsLiquidationUnavailable.missingmaintenancefraction),
            .missingMaintenanceFraction
        )
        XCTAssertEqual(PerpsLiquidationReasonMapper.map(PerpsLiquidationUnavailable.zerodenominator), .zeroDenominator)
        XCTAssertEqual(PerpsLiquidationReasonMapper.map(PerpsLiquidationUnavailable.negativeprice), .negativePrice)
        XCTAssertEqual(PerpsLiquidationReasonMapper.map(nil), .unknown)
    }

    func testADisabledMarketDoesNotBlameTheCallersRegion() {
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(tradeFailure(kind: PerpsTradeError.tradingdisabled)),
            .tradingUnavailable
        )
    }

    func testAnUnsupportedMarketReadsTheSameWay() {
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(tradeFailure(kind: PerpsTradeError.unsupportedmarket)),
            .tradingUnavailable
        )
    }

    func testAPriceThatMovedIsNotAThinBook() {
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(tradeFailure(kind: PerpsTradeError.slippageexceeded)),
            .slippageExceeded
        )
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(tradeFailure(kind: PerpsTradeError.insufficientliquidity)),
            .insufficientLiquidity
        )
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(tradeFailure(kind: PerpsTradeError.needsmoredepth)),
            .insufficientLiquidity
        )
    }

    func testARefusedAutoCloseNamesTheLegThePlannerBlamed() {
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(tradeFailure(kind: PerpsTradeError.invalidautoclose, field: "takeProfit")),
            .invalidAutoClose(.takeProfit)
        )
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(tradeFailure(kind: PerpsTradeError.invalidautoclose, field: "stopLoss")),
            .invalidAutoClose(.stopLoss)
        )
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(
                tradeFailure(kind: PerpsTradeError.invalidautoclose, field: "replacedTakeProfitOrderIndex")
            ),
            .invalidAutoClose(nil)
        )
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(tradeFailure(kind: PerpsTradeError.invalidautoclose)),
            .invalidAutoClose(nil)
        )
    }

    func testRefusalsTheUserCanActOnKeepTheirOwnKind() {
        XCTAssertEqual(PerpsTradingErrorMapper.map(tradeFailure(kind: PerpsTradeError.invalidinput)), .invalidAmount)
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(tradeFailure(kind: PerpsTradeError.unrepresentablevalue)),
            .invalidAmount
        )
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(tradeFailure(kind: PerpsTradeError.conflictingposition)),
            .conflictingPosition
        )
        XCTAssertEqual(PerpsTradingErrorMapper.map(tradeFailure(kind: PerpsTradeError.exceedsposition)), .exceedsPosition)
        XCTAssertEqual(PerpsTradingErrorMapper.map(tradeFailure(kind: PerpsTradeError.ordernotfound)), .orderNotFound)
        XCTAssertEqual(PerpsTradingErrorMapper.map(tradeFailure(kind: PerpsTradeError.noposition)), .positionNotFound)
        XCTAssertEqual(PerpsTradingErrorMapper.map(tradeFailure(kind: PerpsTradeError.invalidnonce)), .validation("refused"))
    }

    func testTheSlippageCapIsTheOneTheCopyNames() {
        let config = PerpsTradingConfig()

        XCTAssertEqual(config.maxSlippage, 0.05, accuracy: 1e-9)
        XCTAssertEqual(config.closeMaxSlippage, 0.05, accuracy: 1e-9)
    }

    func testARefusedPlanCarriesItsKindAndReasonIntoTheLog() {
        let failure = PerpsTradeFailure(
            exception: PerpsTradeException(
                kind: PerpsTradeError.staleinput,
                message: "market snapshot source is stale",
                field: "marketSnapshot",
                suggestion: nil,
                cause: nil
            )
        )

        XCTAssertEqual(PerpsTradingErrorMapper.map(failure), .stalePreparedTransaction)
        XCTAssertTrue(failure.logDescription.contains("market snapshot source is stale"), failure.logDescription)
        XCTAssertTrue(failure.logDescription.contains("marketSnapshot"), failure.logDescription)
        XCTAssertTrue(
            failure.logDescription.lowercased().contains("staleinput"),
            failure.logDescription
        )
    }

    private func tradeFailure(kind: PerpsTradeError, field: String? = nil) -> Error {
        NSError(
            domain: "ChainKitPerpsTrade",
            code: 1,
            userInfo: [
                "KotlinException": PerpsTradeException(
                    kind: kind,
                    message: "refused",
                    field: field,
                    suggestion: nil,
                    cause: nil
                ),
            ]
        )
    }

    func testMapsTypedFoundationNetworkErrors() {
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)),
            .timeout
        )
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(
                NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
            ),
            .offline
        )
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse)),
            .serverUnavailable
        )
    }

    func testInitialMarginBpsNeverBuysMoreLeverageThanAsked() {
        for leverage in [1.0, 2.0, 2.5, 3.0, 8.0, 12.5, 20.0, 27.0, 50.0] {
            let bps = PerpsPlannerMapping.initialMarginBps(leverage: leverage)
            XCTAssertGreaterThan(bps, 0)
            let effective = 10000.0 / Double(bps)
            XCTAssertLessThanOrEqual(
                effective,
                leverage + 1e-9,
                "\(leverage)x must not settle on \(effective)x"
            )
        }
    }

    func testInitialMarginBpsRoundsTheFractionUp() {
        XCTAssertEqual(PerpsPlannerMapping.initialMarginBps(leverage: 1), 10000)
        XCTAssertEqual(PerpsPlannerMapping.initialMarginBps(leverage: 3), 3334)
        XCTAssertEqual(PerpsPlannerMapping.initialMarginBps(leverage: 27), 371)
    }

    func testDoesNotInferErrorKindFromArbitraryMessageText() {
        let error = NSError(
            domain: "PerpsTradingMappersTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "network balance slippage timeout"]
        )

        guard case .unknown = PerpsTradingErrorMapper.map(error) else {
            return XCTFail("untyped errors must stay unknown")
        }
    }
}
