import Foundation
import HTTPTypes
@testable import KeeperCore
import OpenAPIRuntime
import XCTest

final class TonAPIStatusMiddlewareTests: XCTestCase {
    func test_errorStatus_throwsTonAPIErrorWithRawBody() async throws {
        let body = #"{"error":"insufficient TON for gas","error_code":50000}"#
        do {
            _ = try await intercept(status: .conflict, body: body)
            XCTFail("expected TonAPIError")
        } catch let error as TonAPIError {
            XCTAssertEqual(error.statusCode, 409)
            XCTAssertEqual(error.body, Data(body.utf8))
            XCTAssertEqual(error.path, "/v2/migration/prepare")
        }
    }

    func test_successStatus_passesResponseThrough() async throws {
        let (response, body) = try await intercept(status: .ok, body: "{}")

        XCTAssertEqual(response.status, .ok)
        let data = try await Data(collecting: XCTUnwrap(body), upTo: 1024)
        XCTAssertEqual(data, Data("{}".utf8))
    }

    func test_tonAPIError_isUnwrappedFromClientError() {
        let underlying = TonAPIError(statusCode: 429, body: nil, path: nil)
        let clientError = ClientError(
            operationID: "getAccount",
            operationInput: "",
            causeDescription: "Middleware threw an error.",
            underlyingError: underlying
        )

        XCTAssertEqual(clientError.tonAPIError?.statusCode, 429)
        XCTAssertNil(URLError(.cancelled).tonAPIError)
    }

    func test_analyticsReason_isStatusAndServerErrorOnOneLine() throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "error": "cannot apply external message\nexitcode=33",
        ])
        let error = TonAPIError(statusCode: 500, body: body, path: "/v2/blockchain/message")

        XCTAssertEqual(error.analyticsReason, "500 cannot apply external message exitcode=33")
    }

    func test_analyticsReason_unwrapsClientError() throws {
        let body = try JSONSerialization.data(withJSONObject: ["error": "duplicate message"])
        let error = ClientError(
            operationID: "sendBlockchainMessage",
            operationInput: "",
            causeDescription: "Middleware threw an error.",
            underlyingError: TonAPIError(statusCode: 406, body: body, path: nil)
        )

        XCTAssertEqual(error.analyticsReason, "406 duplicate message")
    }

    func test_analyticsReason_withoutErrorBody_isStatus() {
        let error = TonAPIError(statusCode: 502, body: Data("<html>".utf8), path: nil)

        XCTAssertEqual(error.analyticsReason, "502")
    }

    func test_analyticsReason_ofTransportFailure_isTheUnderlyingErrorNotTheClientWrapper() {
        let error = ClientError(
            operationID: "sendBlockchainMessage",
            operationInput: "",
            causeDescription: "Transport threw an error.",
            underlyingError: URLError(.timedOut)
        )

        XCTAssertEqual(error.analyticsReason, URLError(.timedOut).logDescription)
        XCTAssertTrue(error.analyticsReason.contains("reason=timedOut"), error.analyticsReason)
    }

    func test_analyticsReason_leavesTheAccountOutOfAFailingURL() throws {
        let account = "9a3f61c0d2b74e85a1c9e2f3b4d5a6c7e8f90123456789abcdef0123456789ab"
        let url = try XCTUnwrap(URL(string: "https://tonapi.io/v2/wallet/0:\(account)/seqno"))
        let error = ClientError(
            operationID: "getAccountSeqno",
            operationInput: "",
            causeDescription: "Transport threw an error.",
            underlyingError: URLError(.notConnectedToInternet, userInfo: [NSURLErrorFailingURLErrorKey: url])
        )

        XCTAssertFalse(error.analyticsReason.contains(account), error.analyticsReason)
        XCTAssertTrue(error.analyticsReason.contains("tonapi.io/v2/wallet/0:<hex>/seqno"), error.analyticsReason)
    }

    func test_analyticsReason_leavesTheAccountOutOfTheServerError() throws {
        let account = "C3D4E5F60718293A4B5C6D7E8F901A2B3C4D5E6F708192A3B4C5D6E7F8091A2B"
        let body = try JSONSerialization.data(withJSONObject: [
            "error": "inbound external message rejected by transaction \(account): exitcode=33",
        ])
        let error = TonAPIError(statusCode: 500, body: body, path: "/v2/blockchain/message")

        XCTAssertEqual(
            error.analyticsReason,
            "500 inbound external message rejected by transaction <hex>: exitcode=33"
        )
    }

    func test_analyticsReason_leavesABase58AddressOut() throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "error": "account TN3W4H6rK2ce4vX9YnFQHwKENnHjoxb3m9 does not exist",
        ])
        let error = TonAPIError(statusCode: 404, body: body, path: nil)

        XCTAssertEqual(error.analyticsReason, "404 account <hex> does not exist")
    }
}

private extension TonAPIStatusMiddlewareTests {
    func intercept(status: HTTPResponse.Status, body: String) async throws -> (HTTPResponse, HTTPBody?) {
        try await TonAPIStatusMiddleware().intercept(
            HTTPRequest(method: .post, scheme: nil, authority: nil, path: "/v2/migration/prepare"),
            body: nil,
            baseURL: URL(string: "https://tonapi.io")!,
            operationID: "prepareMigration",
            next: { _, _, _ in (HTTPResponse(status: status), HTTPBody(Data(body.utf8))) }
        )
    }
}
