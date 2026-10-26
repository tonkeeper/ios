@testable import App
import BigInt
import XCTest

final class RampDataSourceDefaultsTests: XCTestCase {
    func test_minorUnits_scalesByFractionDigits() {
        XCTAssertEqual(RampDataSourceDefaults.minorUnits(20, fractionDigits: 2), BigUInt(2000))
        XCTAssertEqual(RampDataSourceDefaults.minorUnits(20, fractionDigits: 0), BigUInt(20))
    }

    func test_minorUnits_roundsUp() throws {
        XCTAssertEqual(try RampDataSourceDefaults.minorUnits(XCTUnwrap(Decimal(string: "20.001")), fractionDigits: 2), BigUInt(2001))
        XCTAssertEqual(try RampDataSourceDefaults.minorUnits(XCTUnwrap(Decimal(string: "0.5")), fractionDigits: 0), BigUInt(1))
    }

    func test_minorUnits_keepsExactDecimals() throws {
        XCTAssertEqual(try RampDataSourceDefaults.minorUnits(XCTUnwrap(Decimal(string: "20.1")), fractionDigits: 2), BigUInt(2010))
    }

    func test_minorUnits_ofNonPositiveValueIsZero() {
        XCTAssertEqual(RampDataSourceDefaults.minorUnits(0, fractionDigits: 2), BigUInt(0))
        XCTAssertEqual(RampDataSourceDefaults.minorUnits(-5, fractionDigits: 2), BigUInt(0))
    }
}
