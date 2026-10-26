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
