import Foundation
import HTTPTypes
@testable import KeeperCore
import OpenAPIRuntime
import SwapAPI
import XCTest

final class MultichainRampAPIErrorMappingTests: XCTestCase {
    func test_notFound_carriesTheBackendMessageAndRequestId() async {
        let api = makeAPI(
            transport: StubTransport(
                result: .response(
                    status: .notFound,
                    body: #"{"error":"asset is gone","code":"asset_not_found","request_id":"req-1"}"#
                )
            )
        )

        let error = await failure(of: api)
        guard case let .notFound(message, requestId) = error else {
            return XCTFail("unexpected error: \(String(describing: error))")
        }
        XCTAssertEqual(message, "asset is gone")
        XCTAssertEqual(requestId, "req-1")
    }

    /// A body the client cannot decode used to escape as an `OpenAPIRuntime` description and reach
    /// the user verbatim.
    func test_undecodableBody_isReportedAsATransportFailure() async {
        let api = makeAPI(
            transport: StubTransport(result: .response(status: .notFound, body: #"{"unexpected":true}"#))
        )

        let error = await failure(of: api)
        guard case let .transportError(diagnostic) = error else {
            return XCTFail("unexpected error: \(String(describing: error))")
        }
        XCTAssertFalse(diagnostic.message.isEmpty)
    }

    func test_cancellation_isNotReportedAsAFailedRequest() async {
        let api = makeAPI(transport: StubTransport(result: .failure(CancellationError())))

        let error = await failure(of: api)
        guard case .cancelled = error else {
            return XCTFail("unexpected error: \(String(describing: error))")
        }
    }

    private func makeAPI(transport: StubTransport) -> MultichainRampAPI {
        MultichainRampAPIImplementation(
            swapAPIClient: SwapAPI.Client(
                serverURL: URL(string: "https://swap.tonkeeper.com")!,
                transport: transport
            ),
            appInfoProvider: StubAppInfoProvider(),
            firebaseUserIdProvider: { nil }
        )
    }

    private func failure(of api: MultichainRampAPI) async -> MultichainRampAPIError? {
        do {
            _ = try await api.getOnrampAsset(assetId: "asset", fiat: nil, walletId: nil)
            XCTFail("expected the request to fail")
            return nil
        } catch let error as MultichainRampAPIError {
            return error
        } catch {
            XCTFail("expected a typed ramp error, got \(error)")
            return nil
        }
    }
}

private struct StubTransport: ClientTransport {
    enum Result {
        case response(status: HTTPResponse.Status, body: String)
        case failure(Error)
    }

    let result: Result

    func send(
        _: HTTPRequest,
        body _: HTTPBody?,
        baseURL _: URL,
        operationID _: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        switch result {
        case let .response(status, body):
            return (HTTPResponse(status: status, headerFields: [.contentType: "application/json"]), HTTPBody(body))
        case let .failure(error):
            throw error
        }
    }
}

private struct StubAppInfoProvider: AppInfoProvider {
    var version: String {
        "1.0"
    }

    var userAgent: String {
        "Tonkeeper/1.0"
    }

    var platform: String {
        "ios"
    }

    var language: String {
        "en"
    }

    var storeCountryCode: String? {
        get async { nil }
    }

    var deviceCountryCode: String? {
        nil
    }

    var isVPNActive: Bool {
        false
    }

    var timeZoneIdentifier: String {
        "UTC"
    }
}
