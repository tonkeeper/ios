@testable import App
import MoonPay
import XCTest

final class MoonPayPaymentDisclosuresTests: XCTestCase {
    func test_noDisclosures_showsNothing() throws {
        XCTAssertTrue(try MoonPayPaymentDisclosures.texts(for: disclosures("[]")).isEmpty)
    }

    func test_bothEEADisclosures_showBothInOrder() throws {
        let texts = try MoonPayPaymentDisclosures.texts(for: disclosures("""
        [{"id":"eea-crypto-asset-risk","version":"1"},{"id":"eea-unregulated-stablecoin-risk","version":"1"}]
        """))

        XCTAssertEqual(texts.count, 2)
        XCTAssertTrue(String(texts[0].characters).hasPrefix("By continuing, you agree to transact with MoonPay Europe"))
        XCTAssertTrue(String(texts[1].characters).hasPrefix("Important: You are about to transact in a stablecoin"))
    }

    func test_termsOfUse_isATappableLink() throws {
        let text = try XCTUnwrap(try MoonPayPaymentDisclosures.texts(for: disclosures("""
        [{"id":"us-transaction-finality","version":"1"}]
        """)).first)

        XCTAssertFalse(String(text.characters).contains("]("))
        XCTAssertTrue(String(text.characters).hasSuffix("with no recourse."))
        let link = text.runs.first { String(text[$0.range].characters) == "Terms of Use" }?.link
        XCTAssertEqual(link, URL(string: "https://www.moonpay.com/legal/terms"))
    }

    func test_unknownDisclosure_fallsBackToTheTransactionFinalityText() throws {
        let texts = try MoonPayPaymentDisclosures.texts(for: disclosures("""
        [{"id":"some-new-disclosure","version":"1"},{"id":"us-transaction-finality","version":"1"}]
        """))

        XCTAssertEqual(texts.count, 1)
        XCTAssertTrue(String(texts[0].characters).hasPrefix("I agree to MoonPay’s Terms of Use"))
    }

    private func disclosures(_ json: String) throws -> [MoonPayBuyQuote.PaymentDisclosure] {
        try JSONDecoder().decode([MoonPayBuyQuote.PaymentDisclosure].self, from: Data(json.utf8))
    }
}
