@testable import KeeperCore
import XCTest

final class TonConnectManifestLoaderTests: XCTestCase {
    override func tearDown() {
        ManifestURLProtocolStub.handler = nil
        super.tearDown()
    }

    func testLoadsManifestWhenOriginsMatchAfterNormalization() async throws {
        let manifestURL = try XCTUnwrap(URL(string: "https://EXAMPLE.com:443/tonconnect-manifest.json"))
        let loader = makeLoader { _ in
            .response(
                statusCode: 200,
                data: self.manifestData(url: "https://example.com/app")
            )
        }

        let manifest = try await loader.load(url: manifestURL)

        XCTAssertEqual(manifest.url, URL(string: "https://example.com/app"))
    }

    func testRejectsManifestWithDifferentHost() async throws {
        let manifestURL = try XCTUnwrap(URL(string: "https://attacker.example/tonconnect-manifest.json"))
        let loader = makeLoader { _ in
            .response(
                statusCode: 200,
                data: self.manifestData(url: "https://legitimate.example")
            )
        }

        await assertInvalidManifest {
            try await loader.load(url: manifestURL)
        }
    }

    func testRejectsManifestWithDifferentScheme() async throws {
        let manifestURL = try XCTUnwrap(URL(string: "http://example.com/tonconnect-manifest.json"))
        let loader = makeLoader { _ in
            .response(
                statusCode: 200,
                data: self.manifestData(url: "https://example.com")
            )
        }

        await assertInvalidManifest {
            try await loader.load(url: manifestURL)
        }
    }

    func testRejectsManifestWithDifferentPort() async throws {
        let manifestURL = try XCTUnwrap(URL(string: "https://example.com:8443/tonconnect-manifest.json"))
        let loader = makeLoader { _ in
            .response(
                statusCode: 200,
                data: self.manifestData(url: "https://example.com")
            )
        }

        await assertInvalidManifest {
            try await loader.load(url: manifestURL)
        }
    }

    func testProxyManifestIsComparedWithOriginalOrigin() async throws {
        let manifestURL = try XCTUnwrap(URL(string: "https://example.com/tonconnect-manifest.json"))
        let loader = makeLoader { request in
            if request.url == manifestURL {
                throw URLError(.timedOut)
            }
            return .response(
                statusCode: 200,
                data: self.manifestData(url: "https://example.com/app")
            )
        }

        let manifest = try await loader.load(url: manifestURL)

        XCTAssertEqual(manifest.url.host, "example.com")
    }

    func testRejectsRedirectResponseWithoutRetryingThroughProxy() async throws {
        let manifestURL = try XCTUnwrap(URL(string: "https://attacker.example/tonconnect-manifest.json"))
        let redirectURL = try XCTUnwrap(URL(string: "https://legitimate.example/tonconnect-manifest.json"))
        let requestedURLs = RequestedURLs()
        let loader = makeLoader { request in
            try requestedURLs.append(XCTUnwrap(request.url))
            return .redirectResponse(redirectURL)
        }

        await assertInvalidManifest {
            try await loader.load(url: manifestURL)
        }
        XCTAssertEqual(requestedURLs.value, [manifestURL])
    }
}

private extension TonConnectManifestLoaderTests {
    func makeLoader(
        handler: @escaping (URLRequest) throws -> ManifestURLProtocolStub.Response
    ) -> TonConnectManifestLoader {
        ManifestURLProtocolStub.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ManifestURLProtocolStub.self]
        return TonConnectManifestLoader(urlSession: URLSession(configuration: configuration))
    }

    func manifestData(url: String) -> Data {
        Data(#"{"url":"\#(url)","name":"Example"}"#.utf8)
    }

    func assertInvalidManifest<T>(
        operation: () async throws -> T
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected invalid manifest")
        } catch TonConnectManifestError.invalidManifest {
        } catch {
            XCTFail("Expected invalid manifest, got \(error)")
        }
    }
}

private final class RequestedURLs {
    private let lock = NSLock()
    private var urls = [URL]()

    var value: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }

    func append(_ url: URL) {
        lock.lock()
        urls.append(url)
        lock.unlock()
    }
}

private final class ManifestURLProtocolStub: URLProtocol {
    enum Response {
        case response(statusCode: Int, data: Data)
        case redirectResponse(URL)
    }

    static var handler: ((URLRequest) throws -> Response)?

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
            switch try handler(request) {
            case let .response(statusCode, data):
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: nil
                )!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            case let .redirectResponse(url):
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 302,
                    httpVersion: nil,
                    headerFields: ["Location": url.absoluteString]
                )!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocolDidFinishLoading(self)
            }
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
