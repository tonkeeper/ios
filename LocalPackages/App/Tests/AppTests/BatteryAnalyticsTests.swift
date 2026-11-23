@testable import App
import KeeperCore
import TKCore
import XCTest

final class BatteryAnalyticsTests: XCTestCase {
    private let allSources: [BatteryAnalyticsSource] = [
        .wallet, .settings, .tronFees, .insufficientFunds, .deeplink, .send, .batteryBanner,
    ]

    func testSourceKeepsTheSameFromInEveryEvent() {
        let expected = ["wallet", "settings", "tron_fees", "insufficient_funds", "deeplink", "send", "battery_banner"]

        XCTAssertEqual(allSources.map(\.batteryOpenFrom.rawValue), expected)
        XCTAssertEqual(allSources.map(\.batterySelectFrom.rawValue), expected)
        XCTAssertEqual(allSources.map(\.batterySuccessFrom.rawValue), expected)
    }

    func testInAppPackMapsToSizeWithoutJetton() {
        let sizes = BatteryIAPPack.allCases.map { BatteryAnalyticsPurchase.fiat(pack: $0, promocode: nil).size }
        XCTAssertEqual(sizes, [.large, .medium, .small])

        let event = BatteryAnalytics.selectEvent(
            source: .settings,
            purchase: .fiat(pack: .medium, promocode: "PROMO")
        )
        XCTAssertEqual(event.type, .fiat)
        XCTAssertEqual(event.size, .medium)
        XCTAssertEqual(event.promo, "PROMO")
        XCTAssertNil(event.jetton)
    }

    func testCryptoOptionMapsToSize() {
        let prefilled = ["large", "medium", "small", "unknown"].map { identifier in
            BatteryAnalyticsPurchase.crypto(option: option(identifier: identifier), token: .ton, promocode: nil).size
        }
        XCTAssertEqual(prefilled, [.large, .medium, .small, .custom])

        XCTAssertEqual(BatteryAnalyticsPurchase.crypto(option: .custom, token: .ton, promocode: nil).size, .custom)
    }

    func testCryptoPurchaseReportsTokenSymbol() {
        let purchase = BatteryAnalyticsPurchase.crypto(option: option(identifier: "small"), token: .ton, promocode: nil)

        let event = BatteryAnalytics.successEvent(source: .insufficientFunds, purchase: purchase)

        XCTAssertEqual(event.from, .insufficientFunds)
        XCTAssertEqual(event.type, .crypto)
        XCTAssertEqual(event.size, .small)
        XCTAssertEqual(event.jetton, TonToken.ton.symbol)
        XCTAssertNil(event.promo)
    }

    func testSelectEventEncodesSchemaKeys() throws {
        let event = BatteryAnalytics.selectEvent(
            source: .tronFees,
            purchase: .crypto(option: .custom, token: .ton, promocode: "PROMO")
        )

        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: String]
        )

        XCTAssertEqual(json, [
            "eventName": "battery_select",
            "from": "tron_fees",
            "type": "crypto",
            "size": "custom",
            "promo": "PROMO",
            "jetton": TonToken.ton.symbol,
        ])
    }

    private func option(identifier: String) -> BatteryRechargeModel.OptionItem {
        .prefilled(
            BatteryRechargeModel.OptionItem.Prefilled(
                identifier: identifier,
                chargesCount: 0,
                tokenAmount: 0,
                tokenSymbol: TonToken.ton.symbol,
                tokenDigits: TonToken.ton.fractionDigits,
                fiatAmount: 0,
                currency: .USD,
                batteryPercent: 0,
                isEnable: true
            )
        )
    }
}
