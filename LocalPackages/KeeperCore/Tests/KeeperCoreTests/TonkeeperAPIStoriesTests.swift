@testable import KeeperCore
import XCTest

final class TonkeeperAPIStoriesTests: XCTestCase {
    override func tearDown() {
        StoriesURLProtocolStub.handler = nil
        super.tearDown()
    }

    func test_loadStories_keepsPageLinks() async throws {
        let api = makeAPI(body: """
        {
          "stories": [{
            "story_id": "perps",
            "preview": "https://example.com/preview.png",
            "is_auto_show": false,
            "main_screen": {"title": "Perps", "description": "Learn", "icon": "https://example.com/icon.png"},
            "pages": [
              {"title": "Intro", "description": "Leverage", "image": "https://example.com/1.png", "include_wallets": []},
              {
                "title": "Risk",
                "description": "By continuing, you agree to the Terms of Use.",
                "image": "https://example.com/2.png",
                "include_wallets": [],
                "links": [{"text": "Terms of Use", "url": "https://tonkeeper.com/terms"}]
              }
            ]
          }]
        }
        """)

        let stories = try await api.loadStories(storyIds: ["perps"], walletId: nil)
        let pages = try XCTUnwrap(stories.first).pages

        XCTAssertNil(pages[0].links)
        XCTAssertEqual(pages[1].links, [.init(text: "Terms of Use", url: "https://tonkeeper.com/terms")])
    }
}

private extension TonkeeperAPIStoriesTests {
    func makeAPI(body: String) -> TonkeeperAPIImplementation {
        StoriesURLProtocolStub.handler = { request in
            let response = try HTTPURLResponse(
                url: XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
            return try (XCTUnwrap(response), Data(body.utf8))
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StoriesURLProtocolStub.self]
        return TonkeeperAPIImplementation(
            urlSession: URLSession(configuration: configuration),
            hostProvider: APIHostProviderStub(),
            appInfoProvider: StubAppInfoProvider(),
            isNewUser: { false }
        )
    }
}

private struct APIHostProviderStub: APIHostProvider {
    var basePath: String {
        get async {
            "https://example.com"
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

private final class StoriesURLProtocolStub: URLProtocol {
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
