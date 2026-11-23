@testable import Perps
import PerpsModels
import XCTest

final class PerpsFormattingTests: XCTestCase {
    func test_inputUsesLocaleSeparatorWithoutLosingTrailingZeros() {
        let russian = PerpsFormatting(amounts: PerpsTestAmountFormatting(), locale: Locale(identifier: "ru_RU"))
        XCTAssertEqual(russian.input("0.00580"), "0,00580")
        XCTAssertEqual(russian.input("4."), "4,")
        XCTAssertEqual(russian.input(""), "")
        XCTAssertEqual(PerpsFormatting.test.input("4.28"), "4.28")
    }

    func test_usd_keepsTheCentsADoubleCarries() {
        XCTAssertEqual(PerpsFormatting.test.usd(0.47), "$0.47")
        XCTAssertEqual(PerpsFormatting.test.usd(1.18), "$1.18")
    }

    func test_usdShort_shortensFromAThousandAndCarriesToTheNextUnit() {
        XCTAssertEqual(PerpsFormatting.test.usdShort(999.5), "$999.50")
        XCTAssertEqual(PerpsFormatting.test.usdShort(999.994), "$999.99")
        XCTAssertEqual(PerpsFormatting.test.usdShort(999.995), "$1K")
        XCTAssertEqual(PerpsFormatting.test.usdShort(999.996), "$1K")
        XCTAssertEqual(PerpsFormatting.test.usdShort(1000), "$1K")
        XCTAssertEqual(PerpsFormatting.test.usdShort(20600), "$20.6K")
        XCTAssertEqual(PerpsFormatting.test.usdShort(20640), "$20.64K")
        XCTAssertEqual(PerpsFormatting.test.usdShort(301_183.96), "$301.18K")
        XCTAssertEqual(PerpsFormatting.test.usdShort(999_994), "$999.99K")
        XCTAssertEqual(PerpsFormatting.test.usdShort(999_999.99), "$1M")
        XCTAssertEqual(PerpsFormatting.test.usdShort(2_364_000), "$2.36M")
        XCTAssertEqual(PerpsFormatting.test.usdShort(1_239_000), "$1.24M")
        XCTAssertEqual(PerpsFormatting.test.usdShort(1_200_000_000), "$1.2B")
        XCTAssertEqual(PerpsFormatting.test.usdShort(999_999_999_999), "$1T")
        XCTAssertEqual(PerpsFormatting.test.usdShort(1_050_000_000_000), "$1.05T")
    }

    func test_marketRow_colorsOnlyAMovedPrice() {
        func row(change: Double) -> PerpsMarketRowItem {
            PerpsMarketRowMapping.item(
                from: PerpsMarketSummary(
                    marketId: 1, symbol: "BTC", name: "Bitcoin", iconURL: nil, maxLeverage: 50,
                    price: 100, priceChangePercent: change, volume24h: 1
                ),
                format: .test
            )
        }

        XCTAssertEqual(row(change: 1.2).isChangePositive, true)
        XCTAssertEqual(row(change: -1.2).isChangePositive, false)
        XCTAssertNil(row(change: 0).isChangePositive)
    }

    func test_price_showsTwoDigitsAndUpToSixBelowOne() {
        XCTAssertEqual(PerpsFormatting.test.price(80721.6), "$80721.60")
        XCTAssertEqual(PerpsFormatting.test.price(29754), "$29754.00")
        XCTAssertEqual(PerpsFormatting.test.price(0.5), "$0.50")
        XCTAssertEqual(PerpsFormatting.test.price(0.0093126), "$0.009313")
        XCTAssertEqual(PerpsFormatting.test.price(0.9999999), "$1.00")
    }

    func test_priceChange_isSignedWithTwoDigits() {
        XCTAssertEqual(PerpsFormatting.test.priceChange(0.88), "+0.88%")
        XCTAssertEqual(PerpsFormatting.test.priceChange(-1.1), "−1.10%")
        XCTAssertEqual(PerpsFormatting.test.priceChange(0.004), "0.00%")
    }
}
