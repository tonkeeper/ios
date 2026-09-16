@testable import App
import KeeperCore
import TKCore
import TKLocalize
import XCTest

final class FeeAssetWalletMigrationTests: XCTestCase {
    func test_tonOnlyBattery_mapsToBatteryCharges() {
        let asset = FeeAsset(
            tonFeeMethod: .battery(charges: 10),
            tronFeeMethod: nil
        )
        XCTAssertEqual(asset, .batteryCharges)
    }

    func test_tonOnlyTon_mapsToCoin() {
        let asset = FeeAsset(
            tonFeeMethod: .ton(amountNano: 100),
            tronFeeMethod: nil
        )
        XCTAssertEqual(asset, .coin)
    }

    func test_tronBattery_mapsToBatteryCharges() {
        let asset = FeeAsset(
            tonFeeMethod: .ton(amountNano: 100),
            tronFeeMethod: .battery(charges: 5)
        )
        XCTAssertEqual(asset, .batteryCharges)
    }

    func test_tronTrx_mapsToCoin() {
        let asset = FeeAsset(
            tonFeeMethod: .battery(charges: 10),
            tronFeeMethod: .trx(amountSun: 50)
        )
        XCTAssertEqual(asset, .coin)
    }

    func test_tonFeeRowUsesGramTitle() {
        XCTAssertEqual(
            WalletMigrationPrepareResult.FeeMethod.ton(amountNano: 100).feeRowMethodTitle,
            TKLocales.ExtraType.ton
        )
        XCTAssertEqual(
            WalletMigrationPrepareResult.FeeMethod.ton(amountNano: 100).networkFeePickerTitle,
            TKLocales.ExtraType.ton
        )
    }

    func test_batteryFeeRowUsesShortTitle_pickerKeepsFullTitle() {
        XCTAssertEqual(
            WalletMigrationPrepareResult.FeeMethod.battery(charges: 10).feeRowMethodTitle,
            TKLocales.Settings.Items.battery
        )
        XCTAssertEqual(
            WalletMigrationTronPrepareResult.FeeMethod.battery(charges: 10).feeRowMethodTitle,
            TKLocales.Settings.Items.battery
        )
        XCTAssertEqual(
            WalletMigrationPrepareResult.FeeMethod.battery(charges: 10).networkFeePickerTitle,
            TKLocales.ExtraType.battery
        )
        XCTAssertEqual(
            WalletMigrationTronPrepareResult.FeeMethod.battery(charges: 10).networkFeePickerTitle,
            TKLocales.ExtraType.battery
        )
    }
}
