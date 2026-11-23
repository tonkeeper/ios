@testable import KeeperCore
import TonSwift
import XCTest

final class NativeSwapFeeMethodTests: XCTestCase {
    private typealias FeeMethod = NativeSwapTransactionConfirmationController.FeeMethod

    func test_candidate_isTheUsersPickFirst() {
        XCTAssertEqual(FeeMethod.candidate(picked: .default, isBatteryEligible: true), .default)
        XCTAssertEqual(FeeMethod.candidate(picked: .battery, isBatteryEligible: false), .battery)
    }

    func test_candidate_withoutAPick_isTheBatteryWhereTheWalletHoldsCharges() {
        XCTAssertEqual(FeeMethod.candidate(picked: nil, isBatteryEligible: true), .battery)
        XCTAssertEqual(FeeMethod.candidate(picked: nil, isBatteryEligible: false), .default)
    }

    func test_batteryTheEmulationWentThrough_paysAndStaysOnOffer() throws {
        let feeMethod = try FeeMethod(
            candidate: .battery,
            emulatedTransferType: .battery(excessAddress: Address.parse(Self.excessAddress)),
            isBatteryEligible: true
        )

        XCTAssertEqual(feeMethod.extraType, .battery)
        XCTAssertEqual(feeMethod.availableTypes, [.battery, .default])
    }

    func test_batteryThatCannotPay_fallsBackToTonAndLeavesTheOffer() {
        let feeMethod = FeeMethod(candidate: .battery, emulatedTransferType: .default, isBatteryEligible: true)

        XCTAssertEqual(feeMethod.extraType, .default)
        XCTAssertEqual(feeMethod.availableTypes, [.default])
    }

    func test_tonPickedByTheUser_keepsTheBatteryOnOffer() {
        let feeMethod = FeeMethod(candidate: .default, emulatedTransferType: .default, isBatteryEligible: true)

        XCTAssertEqual(feeMethod.extraType, .default)
        XCTAssertEqual(feeMethod.availableTypes, [.battery, .default])
    }

    func test_walletWithoutCharges_paysWithTonAlone() {
        let feeMethod = FeeMethod(candidate: .default, emulatedTransferType: .default, isBatteryEligible: false)

        XCTAssertEqual(feeMethod.extraType, .default)
        XCTAssertEqual(feeMethod.availableTypes, [.default])
    }
}

private extension NativeSwapFeeMethodTests {
    static let excessAddress = "0:0000000000000000000000000000000000000000000000000000000000000000"
}
