import BigInt
@testable import KeeperCore
import TonSwift
import TronSwift
import XCTest

final class WalletMigrationTronFeeOptionsTests: XCTestCase {
    func test_resolveKeepsOnlyBatteryAndTrx() {
        let methods = WalletMigrationTronFeeOptionsResolver.resolve(
            availableTypes: [
                .battery,
                .default,
                .gasless(token: makeToken(symbol: TRX.symbol)),
            ],
            requiredBatteryCharges: 7,
            requiredTRXSun: 42
        )

        XCTAssertEqual(methods, [
            .battery(charges: 7),
            .trx(amountSun: 42),
        ])
    }

    func test_resolveIgnoresNonTrxGaslessMethod() {
        let methods = WalletMigrationTronFeeOptionsResolver.resolve(
            availableTypes: [
                .battery,
                .gasless(token: makeToken(symbol: USDT.symbol)),
            ],
            requiredBatteryCharges: 7,
            requiredTRXSun: 42
        )

        XCTAssertEqual(methods, [.battery(charges: 7)])
    }

    func test_resolveOmitsBatteryWhenEstimateHasNoCharges() {
        let methods = WalletMigrationTronFeeOptionsResolver.resolve(
            availableTypes: [
                .battery,
                .gasless(token: makeToken(symbol: TRX.symbol)),
            ],
            requiredBatteryCharges: 0,
            requiredTRXSun: 42
        )

        XCTAssertEqual(methods, [.trx(amountSun: 42)])
    }

    func test_resolveKeepsOnlyTrxInTrxOnlyRegion() {
        let methods = WalletMigrationTronFeeOptionsResolver.resolve(
            availableTypes: [
                .gasless(token: makeToken(symbol: TRX.symbol)),
            ],
            requiredBatteryCharges: 7,
            requiredTRXSun: 42
        )

        XCTAssertEqual(methods, [.trx(amountSun: 42)])
    }

    func test_resolveKeepsOnlyTrxForInactiveAccount() {
        let methods = WalletMigrationTronFeeOptionsResolver.resolve(
            availableTypes: [
                .battery,
                .gasless(token: makeToken(symbol: TRX.symbol)),
            ],
            requiredBatteryCharges: 7,
            requiredTRXSun: 42,
            isAccountActivated: false
        )

        XCTAssertEqual(methods, [.trx(amountSun: 42)])
    }

    private func makeToken(symbol: String) -> JettonInfo {
        JettonInfo(
            isTransferable: true,
            hasCustomPayload: false,
            address: try! Address.parse("0:0000000000000000000000000000000000000000000000000000000000000001"),
            fractionDigits: 6,
            name: symbol,
            symbol: symbol,
            verification: .whitelist,
            imageURL: nil
        )
    }
}
