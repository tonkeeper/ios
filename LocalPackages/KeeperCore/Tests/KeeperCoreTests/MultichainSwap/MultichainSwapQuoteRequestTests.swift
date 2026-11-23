@testable import KeeperCore
import SwapAPI
import XCTest

final class MultichainSwapQuoteRequestTests: XCTestCase {
    func test_sourceAmount_asksForExactInput() {
        let body = requestBody(amount: .source(1_000_000_000))

        XCTAssertEqual(body.exact_type, .exact_input)
        XCTAssertEqual(body.source_amount, "1000000000")
        XCTAssertNil(body.destination_amount)
    }

    func test_destinationAmount_asksForExactOutput() {
        let body = requestBody(amount: .destination(20_000_000_000))

        XCTAssertEqual(body.exact_type, .exact_output)
        XCTAssertEqual(body.destination_amount, "20000000000")
        XCTAssertNil(body.source_amount)
    }

    func test_sourceAmount_asksV3ForExactInput() {
        let body = requestBodyV3(amount: .source(1_000_000_000))

        XCTAssertEqual(body.exact_type, .exact_input)
        XCTAssertEqual(body.source_amount, "1000000000")
        XCTAssertNil(body.destination_amount)
    }

    func test_destinationAmount_asksV3ForExactOutput() {
        let body = requestBodyV3(amount: .destination(20_000_000_000))

        XCTAssertEqual(body.exact_type, .exact_output)
        XCTAssertEqual(body.destination_amount, "20000000000")
        XCTAssertNil(body.source_amount)
    }
}

private extension MultichainSwapQuoteRequestTests {
    func request(amount: MultichainSwapQuoteAmount) -> MultichainSwapQuoteRequest {
        MultichainSwapQuoteRequest(
            sourceAsset: "eth/mainnet/coin",
            destinationAsset: "ton/mainnet/coin",
            amount: amount,
            senderAddress: "0xwallet",
            recipientAddress: "tonwallet"
        )
    }

    func requestBody(
        amount: MultichainSwapQuoteAmount
    ) -> SwapAPI.Components.RequestBodies.CrossSwapQuote.jsonPayload {
        switch request(amount: amount).swapAPIRequestBody() {
        case let .json(body):
            return body
        }
    }

    func requestBodyV3(amount: MultichainSwapQuoteAmount) -> SwapAPI.Components.Schemas.CrossSwapQuoteRequest {
        switch request(amount: amount).swapAPIRequestBodyV3() {
        case let .json(body):
            return body
        }
    }
}
