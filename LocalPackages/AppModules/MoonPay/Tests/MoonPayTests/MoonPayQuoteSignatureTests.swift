@testable import MoonPay
import XCTest

final class MoonPayQuoteSignatureTests: XCTestCase {
    func testDecodesJWTPayloadWithBase64URL() throws {
        let payload = #"{"signature":"s","wallet":{"address":"EQ..."},"paymentMethod":{"type":"card"},"source":{"amount":"30","asset":{"code":"USD"}},"destination":{"amount":"5.1","asset":{"code":"TON"}},"executable":true,"~":"?"}"#
        let token = "eyJhbGciOiJIUzI1NiJ9." + base64URL(payload) + ".sig"

        let decoded = try XCTUnwrap(MoonPayQuoteSignature.payload(of: token))

        XCTAssertEqual(decoded["paymentMethod"]?["type"]?.stringValue, "card")
        XCTAssertEqual(decoded["executable"]?.boolValue, true)
        XCTAssertEqual(MoonPayQuoteSignature.missingPaymentFrameFields(in: decoded), [])
    }

    func testReportsFieldsPaymentFramesRequire() throws {
        let payload = #"{"signature":"s","wallet":{"address":"EQ..."},"paymentMethod":null,"source":{"amount":"30","asset":{"code":"USD"}},"destination":{"asset":{"code":"TON"}}}"#
        let decoded = try XCTUnwrap(MoonPayQuoteSignature.payload(of: "h." + base64URL(payload) + ".s"))

        XCTAssertEqual(
            MoonPayQuoteSignature.missingPaymentFrameFields(in: decoded),
            ["paymentMethod.type", "destination.amount"]
        )
    }

    func testRejectsNonJWTInput() {
        XCTAssertNil(MoonPayQuoteSignature.payload(of: "cXVvdGUuc2lnbmF0dXJl"))
        XCTAssertNil(MoonPayQuoteSignature.payload(of: "a.not-base64!.c"))
        XCTAssertNil(MoonPayQuoteSignature.payload(of: ""))
    }

    private func base64URL(_ string: String) -> String {
        Data(string.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
