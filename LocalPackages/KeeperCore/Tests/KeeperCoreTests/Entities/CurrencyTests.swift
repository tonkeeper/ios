import Foundation
@testable import KeeperCore
import XCTest

final class CurrencyTests: XCTestCase {
    func test_codeIsNormalized() {
        XCTAssertEqual(Currency(code: "usd"), .USD)
        XCTAssertEqual(Currency(code: " eur ")?.code, "EUR")
        XCTAssertEqual(Currency(code: "nok")?.code, "NOK")
    }

    func test_emptyCodeIsNil() {
        XCTAssertNil(Currency(code: ""))
        XCTAssertNil(Currency(code: "   "))
        XCTAssertNil(Currency(rawValue: "\n"))
    }

    func test_legacyTonCodeMapsToGram() throws {
        XCTAssertEqual(Currency(rawValue: "TON"), .GRAM)
        XCTAssertEqual(Currency(code: " ton "), .GRAM)
        XCTAssertEqual(Currency(code: "GRAM"), .GRAM)

        let currency = try JSONDecoder().decode(Currency.self, from: Data(#""TON""#.utf8))
        XCTAssertEqual(currency, .GRAM)

        let data = try JSONEncoder().encode(currency)
        XCTAssertEqual(String(data: data, encoding: .utf8), #""GRAM""#)
    }

    func test_unknownCodeIsPreserved() throws {
        let currency = try XCTUnwrap(Currency(code: "NOK"))

        XCTAssertEqual(currency.code, "NOK")
        XCTAssertEqual(currency.rawValue, "NOK")
        XCTAssertEqual(currency.symbol, "NOK")
        XCTAssertFalse(currency.symbolOnLeft)
        XCTAssertEqual(currency.currencyDisplayType, .fiat)
    }

    func test_knownFormattingMetadataIsKept() {
        XCTAssertEqual(Currency.USD.symbol, "$")
        XCTAssertTrue(Currency.USD.symbolOnLeft)
        XCTAssertEqual(Currency(code: "RUB")?.symbol, "₽")
        XCTAssertEqual(Currency(code: "RUB")?.symbolOnLeft, false)
        XCTAssertEqual(Currency(code: "JPY")?.symbol, "¥")
        XCTAssertEqual(Currency.GRAM.symbol, TonInfo.symbol)
        XCTAssertEqual(Currency.GRAM.currencyDisplayType, .token)
        XCTAssertEqual(Currency.BTC.currencyDisplayType, .token)
    }

    func test_unknownCodeRoundTripsThroughCodable() throws {
        let currency = try JSONDecoder().decode(Currency.self, from: Data(#""NOK""#.utf8))

        XCTAssertEqual(currency.code, "NOK")

        let data = try JSONEncoder().encode(currency)
        XCTAssertEqual(String(data: data, encoding: .utf8), #""NOK""#)
    }

    func test_emptyCodeFailsToDecode() {
        XCTAssertThrowsError(try JSONDecoder().decode(Currency.self, from: Data(#""""#.utf8)))
    }
}
