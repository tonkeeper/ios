import Foundation
@testable import KeeperCore
import XCTest

final class BatteryChargesRoundingTests: XCTestCase {
    func testPositiveRemainderCountsAsWholeCharge() {
        XCTAssertEqual(BatteryCalculation.roundCharges(NSDecimalNumber(string: "3.2")), 4)
        XCTAssertEqual(BatteryCalculation.roundCharges(NSDecimalNumber(string: "0.1")), 1)
        XCTAssertEqual(BatteryCalculation.roundCharges(NSDecimalNumber(string: "3")), 3)
    }

    /// A refund deficit reports its full magnitude: -3.2 charges owed is -4, not -3.
    func testNegativeRemainderRoundsAwayFromZero() {
        XCTAssertEqual(BatteryCalculation.roundCharges(NSDecimalNumber(string: "-3.2")), -4)
        XCTAssertEqual(BatteryCalculation.roundCharges(NSDecimalNumber(string: "-0.1")), -1)
        XCTAssertEqual(BatteryCalculation.roundCharges(NSDecimalNumber(string: "-126")), -126)
    }

    func testZeroStaysZero() {
        XCTAssertEqual(BatteryCalculation.roundCharges(NSDecimalNumber.zero), 0)
    }
}
