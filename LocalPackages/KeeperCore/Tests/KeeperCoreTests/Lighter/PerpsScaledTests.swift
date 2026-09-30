@testable import KeeperCore
import XCTest

final class PerpsScaledTests: XCTestCase {
    func testScaleRepresentsPricesBelowOneTenThousandth() throws {
        XCTAssertEqual(try PerpsScaled.scale(9e-05, decimals: 6), 90)
        XCTAssertEqual(try PerpsScaled.scale(1e-08, decimals: 8), 1)
        XCTAssertEqual(try PerpsScaled.scale(0.0001, decimals: 4), 1)
        XCTAssertEqual(try PerpsScaled.scale(66141.7, decimals: 2), 6_614_170)
    }

    func testScaleRoundsAFloatingPointTailToTheScale() throws {
        XCTAssertEqual(try PerpsScaled.scale(0.3 - 0.1, decimals: 4), 2000)
        XCTAssertEqual(try PerpsScaled.scale(1.1 - 0.7, decimals: 4), 4000)
    }

    func testScaleRefusesWhatNoAmountCanBe() {
        XCTAssertThrowsError(try PerpsScaled.scale(-1, decimals: 2))
        XCTAssertThrowsError(try PerpsScaled.scale(.nan, decimals: 2))
        XCTAssertThrowsError(try PerpsScaled.scale(.infinity, decimals: 2))
    }

    func testFeePercentRoundsUpToWholePartsPerMillion() throws {
        XCTAssertEqual(try PerpsScaled.ppm(percent: "0.045"), 450)
        XCTAssertEqual(try PerpsScaled.ppm(percent: "0.00025"), 3)
        XCTAssertEqual(try PerpsScaled.ppm(percent: "0"), 0)
    }

    func testDecimalStringKeepsATinyAmountAboveZero() {
        XCTAssertEqual(PerpsScaled.decimalString(1, decimals: 12), "0.00000001")
        XCTAssertEqual(PerpsScaled.decimalString(1_500_000, decimals: 6), "1.5")
        XCTAssertEqual(PerpsScaled.decimalString(0, decimals: 6), "0")
    }

    func testMarkPriceFallsBackToTheBackendWhenTheLiveTickCannotBeScaled() throws {
        let fallback = try XCTUnwrap(PerpsPlannerMapping.markPrice("2000.5", live: 1e-12, decimals: 2, nowUnixMs: 1))
        XCTAssertEqual(fallback.price, 200_050)
        let live = try XCTUnwrap(PerpsPlannerMapping.markPrice("2000.5", live: 2001, decimals: 2, nowUnixMs: 1))
        XCTAssertEqual(live.price, 200_100)
        XCTAssertNil(try PerpsPlannerMapping.markPrice(nil, live: nil, decimals: 2, nowUnixMs: 1))
    }
}
