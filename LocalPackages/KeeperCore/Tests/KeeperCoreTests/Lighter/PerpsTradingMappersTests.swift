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
