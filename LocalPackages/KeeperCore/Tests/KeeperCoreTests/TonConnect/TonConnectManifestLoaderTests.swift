@testable import KeeperCore
import XCTest

final class TonConnectManifestLoaderTests: XCTestCase {
    override func tearDown() {
        ManifestURLProtocolStub.handler = nil
        super.tearDown()
    }

    func testLoadsManifestHostedOnDifferentOriginThanDeclaredURL() async throws {
        let manifestURL = try XCTUnwrap(URL(string: "https://cdn.example.com/tonconnect-manifest.json"))
        let loader = makeLoader { _ in
            self.manifestData(url: "https://app.example.com")
        }

        let manifest = try await loader.load(url: manifestURL)

        XCTAssertEqual(manifest.url, URL(string: "https://app.example.com"))
    }

    func testFallsBackToProxyWhenDirectLoadFails() async throws {
        let manifestURL = try XCTUnwrap(URL(string: "https://example.com/tonconnect-manifest.json"))
        var proxyRequestURL: URL?
        let loader = makeLoader { request in
            if request.url == manifestURL {
                throw URLError(.timedOut)
            }
            proxyRequestURL = request.url
            return self.manifestData(url: "https://example.com/app")
        }

        let manifest = try await loader.load(url: manifestURL)

        XCTAssertEqual(manifest.url.host, "example.com")
        XCTAssertEqual(proxyRequestURL, manifestURL.proxyURL(noCache: true))
    }

    func testProxyURLKeepsBase64PaddingWithURLSafeAlphabet() throws {
        let manifestURL = try XCTUnwrap(URL(string: "https://example.com/m.json?v=~~~"))
        let encodedURL = URLQueryItem(name: "url", value: "aHR0cHM6Ly9leGFtcGxlLmNvbS9tLmpzb24_dj1-fn4=")

        let proxyURL = try XCTUnwrap(manifestURL.proxyURL)
        let components = try XCTUnwrap(URLComponents(url: proxyURL, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.host, "c.tonapi.io")
        XCTAssertEqual(components.path, "/json")
        XCTAssertEqual(components.queryItems, [encodedURL])

        let uncachedURL = try XCTUnwrap(manifestURL.proxyURL(noCache: true))
        XCTAssertEqual(
            URLComponents(url: uncachedURL, resolvingAgainstBaseURL: false)?.queryItems,
            [encodedURL, URLQueryItem(name: "no-cache", value: "true")]
        )
    }

    func testRejectsManifestWhoseURLHasNoDomain() async throws {
        let manifestURL = try XCTUnwrap(URL(string: "https://example.com/tonconnect-manifest.json"))
        let loader = makeLoader { _ in
            self.manifestData(url: "https://localhost")
        }

        do {
            _ = try await loader.load(url: manifestURL)
            XCTFail("Expected invalid manifest")
        } catch TonConnectManifestError.invalidManifest {
        } catch {
            XCTFail("Expected invalid manifest, got \(error)")
        }
    }
}

private extension TonConnectManifestLoaderTests {
    func makeLoader(
        handler: @escaping (URLRequest) throws -> Data
    ) -> TonConnectManifestLoader {
        ManifestURLProtocolStub.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ManifestURLProtocolStub.self]
        return TonConnectManifestLoader(urlSession: URLSession(configuration: configuration))
    }

    func manifestData(url: String) -> Data {
        Data(#"{"url":"\#(url)","name":"Example"}"#.utf8)
    }
}

private final class ManifestURLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> Data)?

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
            let data = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
