import BigInt
@testable import KeeperCore
import XCTest

final class PerpsFundingAmountTests: XCTestCase {
    func testDeclaredAmountKeepsOnlyTheDigitsThatMatter() {
        XCTAssertEqual(PerpsFundingAmount.declaredAmount(units: BigUInt(25_000_000), decimals: 6), "25")
        XCTAssertEqual(PerpsFundingAmount.declaredAmount(units: BigUInt(24_970_000), decimals: 6), "24.97")
        XCTAssertEqual(PerpsFundingAmount.declaredAmount(units: BigUInt(1), decimals: 6), "0.000001")
        XCTAssertEqual(PerpsFundingAmount.declaredAmount(units: BigUInt(0), decimals: 6), "0")
        XCTAssertEqual(PerpsFundingAmount.declaredAmount(units: BigUInt(999_999), decimals: 6), "0.999999")
    }

    func testDeclaredAmountOfALargeBalanceStaysPlainDigits() throws {
        let units = try XCTUnwrap(BigUInt("123456789012345678901234567890"))

        let declared = PerpsFundingAmount.declaredAmount(units: units, decimals: 6)

        XCTAssertEqual(declared, "123456789012345678901234.56789")
        XCTAssertFalse(declared.contains("e"))
        XCTAssertFalse(declared.contains(","))
    }

    func testUnitsRoundTripThroughTheDeclaredForm() throws {
        for units in [BigUInt(1), BigUInt(999_999), BigUInt(1_000_000), BigUInt(25_000_000)] {
            let declared = PerpsFundingAmount.declaredAmount(units: units, decimals: 6)
            XCTAssertEqual(try PerpsFundingAmount.units(declaredAmount: declared, decimals: 6), units)
        }
    }

    func testAnAmountFinerThanTheAssetIsRefused() {
        XCTAssertThrowsError(try PerpsFundingAmount.units(declaredAmount: "1.0000001", decimals: 6)) { error in
            XCTAssertEqual(error as? PerpsFundingAmountError, .tooPrecise("1.0000001"))
        }
    }

    func testAmountsThatAreNotPlainDecimalsAreRefused() {
        for value in ["", " 1", "1,5", "1e6", "-1", "1.2.3", "+1", "1 000"] {
            XCTAssertThrowsError(
                try PerpsFundingAmount.units(declaredAmount: value, decimals: 6),
                "\(value) must not parse"
            ) { error in
                XCTAssertEqual(error as? PerpsFundingAmountError, .malformed(value))
            }
        }
    }

    func testAnAmountWithNoIntegerPartStillParses() throws {
        XCTAssertEqual(try PerpsFundingAmount.units(declaredAmount: ".5", decimals: 6), BigUInt(500_000))
        XCTAssertEqual(try PerpsFundingAmount.units(declaredAmount: "5.", decimals: 6), BigUInt(5_000_000))
    }

    func testTheGatewayFloorIsOneUsdc() throws {
        let belowFloor = try PerpsFundingAmount.units(declaredAmount: "0.999999", decimals: 6)
        let atFloor = try PerpsFundingAmount.units(declaredAmount: "1", decimals: 6)

        XCTAssertLessThan(belowFloor, PerpsFundingAmount.gatewayMinimumUsdcUnits)
        XCTAssertEqual(atFloor, PerpsFundingAmount.gatewayMinimumUsdcUnits)
    }

    func testAnAmountTheVenuePayloadCannotCarryIsRefusedBeforeSigning() {
        XCTAssertEqual(try? PerpsFundingAmount.int64Units(BigUInt(Int64.max)), Int64.max)
        XCTAssertThrowsError(try PerpsFundingAmount.int64Units(BigUInt(Int64.max) + 1)) { error in
            XCTAssertEqual(error as? PerpsFundingAmountError, .outOfRange("9223372036854775808"))
        }
    }
}
