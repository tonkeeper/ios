@testable import App
import Foundation
import KeeperCore
import XCTest

final class TradeAssetDetailsFormattersTests: XCTestCase {
    /// Abbreviation belongs to `.compact` itself: M/B/T from 1e6 up, grouped digits below it.
    func test_formatTradingAmount_abbreviatesFromOneMillion() {
        let formatter = makeDisplayFormatter()

        XCTAssertEqual(formatter.formatTradingAmount("999995"), "$999 995")
        XCTAssertEqual(formatter.formatTradingAmount("999999"), "$999 999")
        XCTAssertEqual(formatter.formatTradingAmount("1234567"), "$1.23M")
        XCTAssertEqual(formatter.formatTradingAmount("1234567890"), "$1.23B")
    }

    /// Digits are cut, not rounded, so a value just under a tier stays on the tier below it.
    func test_formatTradingAmount_doesNotCarryIntoNextAbbreviation() {
        let formatter = makeDisplayFormatter()

        XCTAssertEqual(formatter.formatTradingAmount("999999000"), "$999.99M")
        XCTAssertEqual(formatter.formatTradingAmount("999999999999"), "$999.99B")
    }
}

private extension TradeAssetDetailsFormattersTests {
    func makeDisplayFormatter() -> TradeAssetDetailsDisplayFormatter {
        let amountFormatter = AmountFormatter(
            configuration: makeAmountFormatterConfiguration(groupDigits: true)
        )
        var signedConfiguration = makeAmountFormatterConfiguration(groupDigits: true)
        signedConfiguration.signPolicy = .always
        let signedAmountFormatter = AmountFormatter(configuration: signedConfiguration)
        let valueFormatter = TradeAssetDetailsValueFormatter(
            amountFormatter: amountFormatter,
            signedAmountFormatter: signedAmountFormatter,
            currencyProvider: { .USD }
        )

        return TradeAssetDetailsDisplayFormatter(
            amountFormatter: amountFormatter,
            valueFormatter: valueFormatter,
            currencyProvider: { .USD }
        )
    }

    func makeAmountFormatterConfiguration(groupDigits: Bool) -> AmountFormatter.Configuration {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.groupDigits = groupDigits
        configuration.space = "\u{2009}"
        return configuration
    }
}
