@testable import App
import MoonPay
import XCTest

@MainActor
final class MoonPayMarketRateTests: XCTestCase {
    /// The quote from TK-6025: 20 USD buys 17.04 USDT after 2.73 USD of fees.
    func test_marketRate_isTheExchangeRateWithoutFees() throws {
        let quote = try Self.quote(exchangeRate: #""1.0133665869346733""#)

        let rate = try XCTUnwrap(MoonPayRampSource.marketRate(of: quote))

        XCTAssertEqual(NSDecimalNumber(decimal: rate).doubleValue, 0.98681, accuracy: 0.00001)
    }

    func test_marketRate_isMissingWithoutAUsableExchangeRate() throws {
        XCTAssertNil(try MoonPayRampSource.marketRate(of: Self.quote(exchangeRate: nil)))
        XCTAssertNil(try MoonPayRampSource.marketRate(of: Self.quote(exchangeRate: #""0""#)))
    }

    func test_formatRate_followsTheDesign() throws {
        XCTAssertEqual(try MoonPayRampViewModel.formatRate(XCTUnwrap(Decimal(string: "0.98681"))), "0.987")
        XCTAssertEqual(try MoonPayRampViewModel.formatRate(XCTUnwrap(Decimal(string: "1.0021"))), "1.002")
        XCTAssertEqual(MoonPayRampViewModel.formatRate(Decimal(74600)), "74\u{00A0}600")
        XCTAssertEqual(try MoonPayRampViewModel.formatRate(XCTUnwrap(Decimal(string: "0.00001341"))), "0.00001341")
    }

    func test_formatDisplayAmount_followsTheAppsPrices() throws {
        let cases: [(String, String)] = [
            ("2492.7214", "2\u{00A0}492.72"),
            ("1.0134", "1.01"),
            ("74600", "74\u{00A0}600"),
            // Below 1, 3 significant digits, with no jump at 0.1.
            ("0.9994", "0.999"),
            ("0.1234", "0.123"),
            ("0.0999", "0.0999"),
            ("0.04921", "0.0492"),
            ("0.00001234", "0.0000123"),
            // Rounded, not cut down, and never abbreviated.
            ("19.999", "20"),
            ("3.5678", "3.57"),
            ("5123456", "5\u{00A0}123\u{00A0}456"),
        ]
        for (value, expected) in cases {
            XCTAssertEqual(try MoonPayRampViewModel.formatDisplayAmount(XCTUnwrap(Decimal(string: value))), expected, value)
        }
    }

    private static func quote(exchangeRate: String?) throws -> MoonPayBuyQuote {
        let rate = exchangeRate.map { #","exchangeRate":\#($0)"# } ?? ""
        let json = #"""
        {
            "source":{"amount":"20","asset":{"code":"USD"}},
            "destination":{"amount":"17.04","asset":{"code":"USDT_TON"}},
            "executable":true,
            "signature":"sig"\#(rate)
        }
        """#
        return try JSONDecoder().decode(MoonPayBuyQuote.self, from: Data(json.utf8))
    }
}
