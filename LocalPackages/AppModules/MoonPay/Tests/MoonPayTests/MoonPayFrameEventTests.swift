@testable import MoonPay
import XCTest

final class MoonPayFrameEventTests: XCTestCase {
    func testActiveConnection() throws {
        let event = try event(#"""
        {"version":2,"meta":{"channelId":"ch_1"},"kind":"complete","payload":{
            "status":"active",
            "customer":{"id":"cus_1","country":"USA","administrativeArea":"NY"},
            "credentials":"ZW5j"
        }}
        """#)
        XCTAssertEqual(
            event,
            .complete(.connection(MoonPayConnectionResult(
                status: .active,
                encryptedCredentials: MoonPayEncryptedCredentials(base64: "ZW5j"),
                customer: MoonPayCustomer(id: "cus_1", country: "USA", administrativeArea: "NY")
            )))
        )
    }

    func testConnectionRequiredWithMismatch() throws {
        let event = try event(#"{"version":2,"meta":{"channelId":"ch_1"},"kind":"complete","payload":{"status":"connectionRequired","credentials":"ZW5j","mismatch":true}}"#)
        XCTAssertEqual(
            event,
            .complete(.connection(MoonPayConnectionResult(
                status: .connectionRequired,
                encryptedCredentials: MoonPayEncryptedCredentials(base64: "ZW5j"),
                mismatch: true
            )))
        )
    }

    func testStatusOnlyConnectionStates() throws {
        XCTAssertEqual(
            try event(#"{"meta":{"channelId":"ch_1"},"kind":"complete","payload":{"status":"termsAcceptanceRequired"}}"#),
            .complete(.connection(MoonPayConnectionResult(status: .termsAcceptanceRequired)))
        )
        XCTAssertEqual(
            try event(#"{"meta":{"channelId":"ch_1"},"kind":"complete","payload":{"status":"failed","reason":"kyc_rejected"}}"#),
            .complete(.connection(MoonPayConnectionResult(status: .failed, reason: "kyc_rejected")))
        )
        XCTAssertEqual(
            try event(#"{"meta":{"channelId":"ch_1"},"kind":"complete","payload":{"status":"somethingNew"}}"#),
            .complete(.status("somethingNew"))
        )
    }

    func testTransactionCreatedAndComplete() throws {
        XCTAssertEqual(
            try event(#"{"meta":{"channelId":"ch_1"},"kind":"transactionCreated","payload":{"transaction":{"id":"txn_01","status":"pending"}}}"#),
            .transactionCreated(MoonPayTransaction(id: "txn_01", status: "pending"))
        )
        let failed = try event(#"{"meta":{"channelId":"ch_1"},"kind":"complete","payload":{"transaction":{"id":"txn_02","status":"failed","failureCode":"authorizationDeclined","failureReason":"Declined"}}}"#)
        guard case let .complete(.transaction(transaction)) = failed else {
            return XCTFail("expected a transaction completion, got \(failed)")
        }
        XCTAssertTrue(transaction.isFailed)
        XCTAssertEqual(transaction.failureCode, "authorizationDeclined")
        XCTAssertEqual(transaction.failureReason, "Declined")
    }

    func testChallengeEvent() throws {
        XCTAssertEqual(
            try event(#"{"meta":{"channelId":"ch_1"},"kind":"challenge","payload":{"kind":"frame","url":"https://platform.moonpay.com/platform/v1/challenge?challengeToken=t"}}"#),
            try .challenge(url: XCTUnwrap(URL(string: "https://platform.moonpay.com/platform/v1/challenge?challengeToken=t")))
        )
    }

    func testChallengeCompletionBranchesOnFlow() throws {
        XCTAssertEqual(
            try event(#"{"meta":{"channelId":"ch_1"},"kind":"complete","payload":{"flow":"buy","transaction":{"id":"txn_03","status":"completed"}}}"#),
            .complete(.transaction(MoonPayTransaction(id: "txn_03", status: "completed")))
        )
        XCTAssertEqual(
            try event(#"{"meta":{"channelId":"ch_1"},"kind":"complete","payload":{"flow":"identity","identityId":"idn_1"}}"#),
            .complete(.identity(id: "idn_1"))
        )
        XCTAssertEqual(
            try event(#"{"meta":{"channelId":"ch_1"},"kind":"complete","payload":{"flow":"guest_checkout_limit_upgrade","status":"upgraded"}}"#),
            .complete(.status("upgraded"))
        )
    }

    func testAddCardCompletion() throws {
        let event = try event(#"""
        {"meta":{"channelId":"ch_1"},"kind":"complete","payload":{"card":{
            "id":"a1b2","type":"card","cardType":"credit","brand":"visa","last4":"4242",
            "expirationMonth":"12","expirationYear":2027,"availability":{"active":true}
        }}}
        """#)
        XCTAssertEqual(
            event,
            .complete(.card(MoonPaySavedCard(
                id: "a1b2",
                type: "card",
                cardType: "credit",
                brand: "visa",
                last4: "4242",
                expirationMonth: "12",
                expirationYear: "2027",
                availability: MoonPaySavedCard.Availability(active: true)
            )))
        )
    }

    func testAddCardCompletionCarriesAvailabilityReasons() throws {
        let event = try event(#"{"meta":{"channelId":"ch_1"},"kind":"complete","payload":{"card":{"id":"c3d4","brand":"mastercard","last4":"8910","availability":{"active":false,"reasons":["card_expired"]}}}}"#)
        guard case let .complete(.card(card)) = event else {
            return XCTFail("expected a card completion, got \(event)")
        }
        XCTAssertEqual(card.availability, MoonPayPaymentMethodAvailability(active: false, reasons: ["card_expired"]))
    }

    func testErrorEvent() throws {
        XCTAssertEqual(
            try event(#"{"meta":{"channelId":"ch_1"},"kind":"error","payload":{"code":"validationError","message":"Bad request","errors":[{"code":"required","message":"clientToken is required"}]}}"#),
            .error(MoonPayFrameError.Remote(
                code: "validationError",
                message: "Bad request",
                errors: [MoonPayErrorDetail(code: "required", message: "clientToken is required")]
            ))
        )
        XCTAssertEqual(
            try event(#"{"meta":{"channelId":"ch_1"},"kind":"error"}"#),
            .error(MoonPayFrameError.Remote(code: "unknown", message: "Unknown error"))
        )
    }

    func testLifecycleAndUnknownKinds() throws {
        XCTAssertEqual(try event(#"{"meta":{"channelId":"ch_1"},"kind":"handshake"}"#), .handshake)
        XCTAssertEqual(try event(#"{"meta":{"channelId":"ch_1"},"kind":"ready"}"#), .ready)
        XCTAssertEqual(try event(#"{"meta":{"channelId":"ch_1"},"kind":"buttonPressed"}"#), .buttonPressed)
        XCTAssertEqual(
            try event(#"{"meta":{"channelId":"ch_1"},"kind":"cancelled","payload":{"flow":"buy"}}"#),
            .cancelled(.object(["flow": .string("buy")]))
        )
        XCTAssertEqual(
            try event(#"{"meta":{"channelId":"ch_1"},"kind":"somethingElse","payload":{"a":1}}"#),
            .unknown(kind: "somethingElse", payload: .object(["a": .number(1)]))
        )
        XCTAssertEqual(
            try event(#"{"meta":{"channelId":"ch_1"},"kind":"complete"}"#),
            .complete(.raw(nil))
        )
    }

    func testCredentialsDecodeISO8601WithAndWithoutFractionalSeconds() throws {
        let decoder = MoonPayJSONCoding.makeDecoder()
        let fractional = try decoder.decode(MoonPayCredentials.self, from: Data(#"{"accessToken":"a","clientToken":"c","expiresAt":"2026-03-27T12:30:00.000Z"}"#.utf8))
        let plain = try decoder.decode(MoonPayCredentials.self, from: Data(#"{"accessToken":"a","clientToken":"c","expiresAt":"2026-03-27T12:30:00Z"}"#.utf8))
        XCTAssertEqual(fractional.expiresAt, plain.expiresAt)
        XCTAssertEqual(fractional.expiresAt.timeIntervalSince1970, 1_774_614_600)
        XCTAssertTrue(fractional.isExpired(at: Date(timeIntervalSince1970: 1_774_614_600)))
        XCTAssertFalse(fractional.isExpired(at: Date(timeIntervalSince1970: 1_774_614_599)))
    }

    private func event(_ json: String) throws -> MoonPayFrameEvent {
        try MoonPayFrameEvent(message: MoonPayFrameMessage.decode(jsonString: json))
    }
}
