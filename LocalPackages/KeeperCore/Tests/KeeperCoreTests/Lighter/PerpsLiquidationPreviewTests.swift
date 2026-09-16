import ChainKit
@testable import KeeperCore
import XCTest

/// Validates the pure liquidation math the leverage sheet previews against, plus
/// the SDK→Core unavailable-reason mapping. Numbers are illustrative; the contract
/// under test is "long liq below mark, short liq above mark, flat → unavailable".
final class PerpsLiquidationPreviewTests: XCTestCase {
    func testLongLiquidationBelowMark() {
        let estimate = LighterRisk.shared.isolatedLiquidation(
            side: LighterTradeSide.long_,
            baseSize: 0.1,
            entryPrice: 100,
            markPrice: 100,
            maintenanceFraction: 0.01,
            collateralUsd: 10
        )
        guard let price = estimate.price?.doubleValue else {
            return XCTFail("expected a long liquidation price")
        }
        XCTAssertLessThan(price, 100)
    }

    func testShortLiquidationAboveMark() {
        let estimate = LighterRisk.shared.isolatedLiquidation(
            side: LighterTradeSide.short_,
            baseSize: 0.1,
            entryPrice: 100,
            markPrice: 100,
            maintenanceFraction: 0.01,
            collateralUsd: 10
        )
        guard let price = estimate.price?.doubleValue else {
            return XCTFail("expected a short liquidation price")
        }
        XCTAssertGreaterThan(price, 100)
    }

    func testFlatPositionReturnsUnavailableNotZero() {
        let estimate = LighterRisk.shared.isolatedLiquidation(
            side: LighterTradeSide.long_,
            baseSize: 0,
            entryPrice: 100,
            markPrice: 100,
            maintenanceFraction: 0.01,
            collateralUsd: 10
        )
        XCTAssertNil(estimate.price)
        XCTAssertNotNil(estimate.unavailableReason)
    }

    func testReasonMapperCoversAllCases() {
        XCTAssertEqual(PerpsLiquidationReasonMapper.map(LighterLiquidationUnavailable.flatPosition), .flatPosition)
        XCTAssertEqual(PerpsLiquidationReasonMapper.map(LighterLiquidationUnavailable.missingMark), .missingMark)
        XCTAssertEqual(PerpsLiquidationReasonMapper.map(LighterLiquidationUnavailable.missingCollateral), .missingCollateral)
        XCTAssertEqual(
            PerpsLiquidationReasonMapper.map(LighterLiquidationUnavailable.missingMaintenanceFraction),
            .missingMaintenanceFraction
        )
        XCTAssertEqual(PerpsLiquidationReasonMapper.map(LighterLiquidationUnavailable.zeroDenominator), .zeroDenominator)
        XCTAssertEqual(PerpsLiquidationReasonMapper.map(LighterLiquidationUnavailable.negativePrice), .negativePrice)
        XCTAssertEqual(PerpsLiquidationReasonMapper.map(nil), .unknown)
    }
}
