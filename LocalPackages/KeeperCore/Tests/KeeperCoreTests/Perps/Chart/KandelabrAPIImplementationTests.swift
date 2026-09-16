import Foundation
@testable import KeeperCore
import XCTest

final class KandelabrAPIImplementationTests: XCTestCase {
    func testCandlesPostsPublicEndpointWithTickerResolutionAndLimit() async throws {
        let api = makeAPI { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/kandelabr/public-api/v1/candles")
            let body = try Self.requestJSON(request)
            XCTAssertEqual(body["ticker"] as? String, "BTC/USD")
            XCTAssertEqual(body["resolution"] as? String, "1h")
            XCTAssertEqual(body["limit"] as? Int ?? (body["limit"] as? NSNumber)?.intValue, 500)
            XCTAssertNil(body["start_ts"])
            XCTAssertNil(body["end_ts"])
            return try Self.httpResponse(
                for: request,
                statusCode: 200,
                body: #"{"ticker":"BTC/USD","resolution":"1h","start_ts":1700000000000,"candles":[{"o":"1","h":"2","l":"0.5","c":"1.5","v":"10"}]}"#
            )
        }

        let response = try await api.candles(
            ticker: "BTC/USD",
            resolution: "1h",
            limit: 500,
            startTs: nil,
            endTs: nil
        )

        XCTAssertEqual(response.ticker, "BTC/USD")
        XCTAssertEqual(response.resolution, "1h")
        XCTAssertEqual(response.candles.count, 1)
        XCTAssertEqual(response.candles.first?.c, "1.5")
    }

    func testCandlesForwardsEndTsWhenPaging() async throws {
        let api = makeAPI { request in
            let body = try Self.requestJSON(request)
            XCTAssertEqual((body["end_ts"] as? NSNumber)?.int64Value, 1_700_000_000_000)
            XCTAssertEqual(body["limit"] as? Int ?? (body["limit"] as? NSNumber)?.intValue, 200)
            return try Self.httpResponse(
                for: request,
                statusCode: 200,
                body: #"{"ticker":"ETH/USD","resolution":"4h","start_ts":1,"candles":[]}"#
            )
        }

        _ = try await api.candles(
            ticker: "ETH/USD",
            resolution: "4h",
            limit: 200,
            startTs: nil,
            endTs: 1_700_000_000_000
        )
    }

    func testCandlesMaps404ToNotFound() async {
        let api = makeAPI { request in
            try Self.httpResponse(
                for: request,
                statusCode: 404,
                body: #"{"status":"NOT_FOUND","message":"ticker not found"}"#
            )
        }

        do {
            _ = try await api.candles(
                ticker: "NOPE/USD",
                resolution: "1m",
                limit: 1,
                startTs: nil,
                endTs: nil
            )
            XCTFail("expected notFound")
        } catch KandelabrAPIError.notFound {
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testCandlesMapsUnknownResolutionToBadRequestWithoutCallingNetwork() async {
        let api = makeAPI { _ in
            XCTFail("unknown resolution must not reach the network")
            throw URLError(.badServerResponse)
        }

        do {
            _ = try await api.candles(
                ticker: "BTC/USD",
                resolution: "12h",
                limit: 10,
                startTs: nil,
                endTs: nil
            )
            XCTFail("expected badRequest")
        } catch KandelabrAPIError.badRequest {
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}

private extension KandelabrAPIImplementationTests {
    func makeAPI(
        handler: @escaping KandelabrAPIURLProtocolStub.Handler
    ) -> KandelabrAPIImplementation {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [KandelabrAPIURLProtocolStub.self]
        let basePath = KandelabrAPIURLProtocolStub.register(handler)
        return KandelabrAPIImplementation(
            hostProvider: KandelabrAPIHostProviderStub(value: basePath),
            urlSession: URLSession(configuration: configuration)
        )
    }

    static func requestJSON(_ request: URLRequest) throws -> [String: Any] {
        let data: Data
        if let body = request.httpBody {
            data = body
        } else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var collected = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: 1024)
                if read > 0 {
                    collected.append(buffer, count: read)
                } else {
                    break
                }
            }
            data = collected
        } else {
            throw URLError(.cannotDecodeContentData)
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    static func httpResponse(
        for request: URLRequest,
        statusCode: Int,
        body: String
    ) throws -> (HTTPURLResponse, Data) {
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: XCTUnwrap(request.url),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
        )
        return try (response, XCTUnwrap(body.data(using: .utf8)))
    }
}

private struct KandelabrAPIHostProviderStub: APIHostProvider {
    let value: String

    var basePath: String {
        get async {
            value
        }
    }
}

private final class KandelabrAPIURLProtocolStub: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let lock = NSLock()
    private static var handlers: [String: Handler] = [:]

    static func register(_ handler: @escaping Handler) -> String {
        let host = "\(UUID().uuidString).example.com"
        lock.lock()
        handlers[host] = handler
        lock.unlock()
        return "https://\(host)"
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let host = request.url?.host,
              let handler = Self.takeHandler(for: host)
        else {
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

    private static func takeHandler(for host: String) -> Handler? {
        lock.lock()
        defer { lock.unlock() }
        return handlers.removeValue(forKey: host)
    }
}
