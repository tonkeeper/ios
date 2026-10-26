@testable import KeeperCore
import XCTest

final class PerpsScaledTests: XCTestCase {
    func testScaleRepresentsPricesBelowOneTenThousandth() throws {
        XCTAssertEqual(try PerpsScaled.scale(9e-05, decimals: 6, rounding: .nearest), 90)
        XCTAssertEqual(try PerpsScaled.scale(1e-08, decimals: 8, rounding: .nearest), 1)
        XCTAssertEqual(try PerpsScaled.scale(0.0001, decimals: 4, rounding: .nearest), 1)
        XCTAssertEqual(try PerpsScaled.scale(66141.7, decimals: 2, rounding: .nearest), 6_614_170)
    }

    func testScaleRoundsAFloatingPointTailToTheScale() throws {
        XCTAssertEqual(try PerpsScaled.scale(0.3 - 0.1, decimals: 4, rounding: .nearest), 2000)
        XCTAssertEqual(try PerpsScaled.scale(1.1 - 0.7, decimals: 4, rounding: .nearest), 4000)
    }

    func testAFigureLongerThanTheScaleRoundsInsteadOfFailing() throws {
        XCTAssertEqual(try PerpsScaled.parse("96.75597216068527", decimals: 3, rounding: .nearest), 96756)
        XCTAssertEqual(try PerpsScaled.parse("1.8386666666666667", decimals: 5, rounding: .nearest), 183_867)
        XCTAssertEqual(try PerpsScaled.parse("101.171", decimals: 3, rounding: .nearest), 101_171)
        XCTAssertEqual(try PerpsScaled.parse("19", decimals: 0, rounding: .nearest), 19)
    }

    func testABoundRoundsAwayFromWhatItBounds() throws {
        XCTAssertEqual(try PerpsScaled.parse("0.0004", decimals: 3, rounding: .up), 1)
        XCTAssertEqual(try PerpsScaled.parse("0.0004", decimals: 3, rounding: .nearest), 0)
        XCTAssertEqual(try PerpsScaled.parse("0.0009", decimals: 3, rounding: .down), 0)
        XCTAssertEqual(try PerpsScaled.parse("2.5", decimals: 0, rounding: .down), 2)
        XCTAssertEqual(try PerpsScaled.parse("2.5", decimals: 0, rounding: .up), 3)
        XCTAssertEqual(try PerpsScaled.parse("2.5", decimals: 0, rounding: .nearest), 3)
    }

    func testAnExactFigureIsUntouchedWhicheverWayItWouldRound() throws {
        for rounding in [PerpsScaled.Rounding.nearest, .down, .up] {
            XCTAssertEqual(try PerpsScaled.parse("123456789.123456", decimals: 6, rounding: rounding), 123_456_789_123_456)
            XCTAssertEqual(try PerpsScaled.parse("0.5", decimals: 1, rounding: rounding), 5)
        }
    }

    func testAScaledParseStillRefusesWhatIsNotADecimal() {
        XCTAssertThrowsError(try PerpsScaled.parse("-1.5", decimals: 2, rounding: .nearest))
        XCTAssertThrowsError(try PerpsScaled.parse("", decimals: 2, rounding: .nearest))
        XCTAssertThrowsError(try PerpsScaled.parse("abc", decimals: 2, rounding: .nearest))
    }

    func testScaleRefusesWhatNoAmountCanBe() {
        XCTAssertThrowsError(try PerpsScaled.scale(-1, decimals: 2, rounding: .nearest))
        XCTAssertThrowsError(try PerpsScaled.scale(.nan, decimals: 2, rounding: .nearest))
        XCTAssertThrowsError(try PerpsScaled.scale(.infinity, decimals: 2, rounding: .nearest))
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
