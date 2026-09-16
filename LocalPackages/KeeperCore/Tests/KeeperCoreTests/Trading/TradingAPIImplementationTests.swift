@testable import KeeperCore
import TKTradingAPI
import XCTest

final class TradingAPIImplementationTests: XCTestCase {
    override func tearDown() {
        TradingAPIURLProtocolStub.handler = nil
        super.tearDown()
    }

    func test_getAssetsCatalog_whenNotFound_throwsBadStatusMessage() async throws {
        let api = try makeAPI(statusCode: 404)

        await assertThrowsBadStatus("Asset missing") {
            _ = try await api.getAssetsCatalog(
                requestContext: makeRequestContext(),
                tab: .tokens,
                query: nil,
                cursor: nil,
                pageSize: nil,
                sourceShelf: nil
            )
        }
    }

    func test_getAssetsCatalogV2_whenNotFound_throwsBadStatusMessage() async throws {
        let api = try makeAPI(statusCode: 404)

        await assertThrowsBadStatus("Asset missing") {
            _ = try await api.getAssetsCatalogV2(
                requestContext: makeRequestContext(),
                tab: .tokens,
                query: nil,
                sort: nil,
                order: nil,
                cursor: nil,
                pageSize: nil,
                sourceShelf: nil
            )
        }
    }

    func test_getAssets_whenNotFound_throwsBadStatusMessage() async throws {
        let api = try makeAPI(statusCode: 404)

        await assertThrowsBadStatus("Asset missing") {
            _ = try await api.getAssets(
                requestContext: makeRequestContext(),
                ids: ["missing"]
            )
        }
    }
}

private extension TradingAPIImplementationTests {
    func makeAPI(statusCode: Int) throws -> TradingAPIImplementation {
        TradingAPIURLProtocolStub.handler = { request in
            let response = try HTTPURLResponse(
                url: XCTUnwrap(request.url),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
            let body = try XCTUnwrap(
                #"{"code":"not_found","message":"Asset missing","request_id":"request-id"}"#.data(using: .utf8)
            )
            return try (XCTUnwrap(response), body)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TradingAPIURLProtocolStub.self]
        return TradingAPIImplementation(
            hostProvider: APIHostProviderStub(),
            urlSession: URLSession(configuration: configuration)
        )
    }

    func makeRequestContext() -> TradingRequestContext {
        TradingRequestContext(
            currency: .USD,
            language: "en",
            userAgent: "test",
            storeCountryCode: nil,
            simCountryCode: nil,
            deviceCountryCode: nil,
            timezoneIdentifier: "UTC",
            isVPNActive: nil
        )
    }

    func assertThrowsBadStatus(
        _ expectedMessage: String,
        _ block: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await block()
            XCTFail("Expected badStatus", file: file, line: line)
        } catch let TradingAPIError.badStatus(message) {
            XCTAssertEqual(message, expectedMessage, file: file, line: line)
        } catch {
            XCTFail("Expected badStatus, got \(error)", file: file, line: line)
        }
    }
}

private struct APIHostProviderStub: APIHostProvider {
    var basePath: String {
        get async {
            "https://example.com"
        }
    }
}

private final class TradingAPIURLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
