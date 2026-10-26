@testable import KeeperCore
import XCTest

final class PushNotificationsAPITests: XCTestCase {
    override func tearDown() {
        PushURLProtocolStub.handler = nil
        super.tearDown()
    }

    func test_unsubscribeDapp_sendsDeleteWithQuery() async throws {
        var captured: URLRequest?
        let api = makeAPI { request in
            captured = request
            return (200, Data())
        }

        let didUnsubscribe = try await api.unsubscribeDappNotifications(
            unsubscribeData: .init(token: "fcm", appURL: "https://dapp.io", account: "0:abc", tonProof: "proof")
        )

        XCTAssertTrue(didUnsubscribe)
        let request = try XCTUnwrap(captured)
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-TonConnect-Auth"), "proof")
        let query = try URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(
            Set(query ?? []),
            [
                URLQueryItem(name: "firebase_token", value: "fcm"),
                URLQueryItem(name: "app_url", value: "https://dapp.io"),
                URLQueryItem(name: "account", value: "0:abc"),
            ]
        )
    }

    func test_unsubscribeDapp_throwsOnErrorStatus() async {
        let api = makeAPI { _ in (404, Data()) }

        do {
            _ = try await api.unsubscribeDappNotifications(
                unsubscribeData: .init(token: "fcm", appURL: "https://dapp.io", account: "0:abc", tonProof: "proof")
            )
            XCTFail("Expected an error")
        } catch {}
    }

    func test_subscribeDapp_errorStatusWithOkBody_throws() async {
        let api = makeAPI { _ in (500, Data(#"{"ok":true}"#.utf8)) }

        do {
            _ = try await api.subscribeDappNotifications(subscribeData: .sample)
            XCTFail("Expected an error")
        } catch {}
    }

    func test_subscribeDapp_successStatus_returnsBodyVerdict() async throws {
        let api = makeAPI { _ in (201, Data(#"{"ok":false}"#.utf8)) }

        let didSubscribe = try await api.subscribeDappNotifications(subscribeData: .sample)

        XCTAssertFalse(didSubscribe)
    }

    private func makeAPI(handler: @escaping (URLRequest) -> (Int, Data)) -> PushNotificationsAPI {
        PushURLProtocolStub.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PushURLProtocolStub.self]
        return PushNotificationsAPI(urlSession: URLSession(configuration: configuration))
    }
}

private extension PushNotificationsAPI.DappSubscribeData {
    static let sample = PushNotificationsAPI.DappSubscribeData(
        token: "fcm",
        appURL: "https://dapp.io",
        account: "0:abc",
        tonProof: "proof",
        sessionId: "session",
        commercial: true,
        silent: false
    )
}

private final class PushURLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) -> (Int, Data))?

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
        let (statusCode, data) = handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
