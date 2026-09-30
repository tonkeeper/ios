import Foundation
@testable import TKCore
import XCTest

actor StubAptabaseURLSession: AptabaseURLSession {
    enum Response: Sendable {
        case status(Int)
        case transportFailure
    }

    private(set) var requests = [URLRequest]()
    private var responses: [Response]

    init(responses: [Response]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let response = responses.count > 1 ? responses.removeFirst() : responses[0]
        switch response {
        case .transportFailure:
            throw URLError(.notConnectedToInternet)
        case let .status(code):
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: code,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), httpResponse)
        }
    }
}

final class AptabaseDispatcherTests: XCTestCase {
    func test_acceptedBatchIsDelivered() async {
        let outcome = await makeDispatcher(responses: [.status(200)]).send([makeEvent()])
        XCTAssertEqual(outcome, .delivered)
    }

    func test_badRequestIsRejectedBecauseRetryingWouldLoopForever() async {
        let outcome = await makeDispatcher(responses: [.status(400)]).send([makeEvent()])
        XCTAssertEqual(outcome, .rejected)
    }

    /// The SDK drops these; the server rate limits at 20 req/s per IP, which is reachable behind NAT.
    func test_rateLimitIsRetried() async {
        let outcome = await makeDispatcher(responses: [.status(429)]).send([makeEvent()])
        XCTAssertEqual(outcome, .retry)
    }

    /// Transient 4xx: the batch itself is fine, only the moment was wrong.
    func test_timeoutStatusesAreRetried() async {
        for status in [408, 425] {
            let outcome = await makeDispatcher(responses: [.status(status)]).send([makeEvent()])
            XCTAssertEqual(outcome, .retry, "status \(status)")
        }
    }

    func test_serverErrorIsRetried() async {
        let outcome = await makeDispatcher(responses: [.status(503)]).send([makeEvent()])
        XCTAssertEqual(outcome, .retry)
    }

    func test_transportFailureIsRetried() async {
        let outcome = await makeDispatcher(responses: [.transportFailure]).send([makeEvent()])
        XCTAssertEqual(outcome, .retry)
    }

    func test_requestMatchesTheIngestionApiContract() async throws {
        let session = StubAptabaseURLSession(responses: [.status(200)])
        let dispatcher = AptabaseDispatcher(
            endpointProvider: { "https://analytics.example.com" },
            appKey: "A-SH-0000000000",
            environment: makeEnvironment(),
            session: session
        )

        _ = await dispatcher.send([makeEvent()])

        let requests = await session.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://analytics.example.com/api/v0/events")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "App-Key"), "A-SH-0000000000")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "iOS/17.0 en")

        let body = try XCTUnwrap(request.httpBody)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [[String: Any]])
        XCTAssertEqual(payload.count, 1)
        XCTAssertEqual(payload[0]["eventName"] as? String, "event")
        XCTAssertEqual(payload[0]["sessionId"] as? String, "1700000000000000")
        // Same shape the SDK sends, so nothing downstream has to change.
        XCTAssertEqual(payload[0]["timestamp"] as? String, "2023-11-14T22:13:20Z")
        let systemProps = try XCTUnwrap(payload[0]["systemProps"] as? [String: Any])
        XCTAssertEqual(systemProps["sdkVersion"] as? String, AptabaseEnvironment.sdkVersion)
        XCTAssertEqual(systemProps["appBuildNumber"] as? String, "1")
    }

    func test_endpointIsReadOnEverySend() async {
        // The dispatcher is built at launch and the boot configuration answers later, so a host
        // captured at init would pin the whole run to the one compiled into the bundle.
        let endpoint = EndpointBox("https://bundled.example.com")
        let session = StubAptabaseURLSession(responses: [.status(200)])
        let dispatcher = AptabaseDispatcher(
            endpointProvider: { endpoint.value },
            appKey: "A-SH-0000000000",
            environment: makeEnvironment(),
            session: session
        )

        _ = await dispatcher.send([makeEvent()])
        endpoint.value = "https://moved.example.com"
        _ = await dispatcher.send([makeEvent()])

        let urls = await session.requests.map(\.url?.absoluteString)
        XCTAssertEqual(urls, [
            "https://bundled.example.com/api/v0/events",
            "https://moved.example.com/api/v0/events",
        ])
    }

    func test_onlyAnAbsoluteHttpHostIsAcceptedFromTheConfiguration() {
        XCTAssertEqual(
            AptabaseConfigurator.usableEndpoint("https://block-analytics.tonkeeper.com"),
            "https://block-analytics.tonkeeper.com"
        )
        XCTAssertEqual(AptabaseConfigurator.usableEndpoint("http://localhost:3000"), "http://localhost:3000")
        // Everything below parses as a URL, which is why the check cannot just be `URL(string:)`.
        XCTAssertNil(AptabaseConfigurator.usableEndpoint("not a url"))
        XCTAssertNil(AptabaseConfigurator.usableEndpoint("block-analytics.tonkeeper.com"))
        XCTAssertNil(AptabaseConfigurator.usableEndpoint("/api/v0/events"))
        XCTAssertNil(AptabaseConfigurator.usableEndpoint("wss://block-analytics.tonkeeper.com"))
        XCTAssertNil(AptabaseConfigurator.usableEndpoint(""))
        XCTAssertNil(AptabaseConfigurator.usableEndpoint(nil))
    }
}

/// Moves the host between sends the way the boot configuration does at runtime.
private final class EndpointBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: String

    init(_ value: String) {
        stored = value
    }

    var value: String {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

private extension AptabaseDispatcherTests {
    func makeDispatcher(responses: [StubAptabaseURLSession.Response]) -> AptabaseDispatcher {
        AptabaseDispatcher(
            endpointProvider: { "https://analytics.example.com" },
            appKey: "A-SH-0000000000",
            environment: makeEnvironment(),
            session: StubAptabaseURLSession(responses: responses)
        )
    }

    func makeEnvironment() -> AptabaseEnvironment {
        AptabaseEnvironment(
            isDebug: false,
            osName: "iOS",
            osVersion: "17.0",
            locale: "en",
            appVersion: "1.0",
            appBuildNumber: "1",
            deviceModel: "iPhone15,2"
        )
    }

    func makeEvent() -> AptabaseEvent {
        AptabaseEvent(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            sessionId: "1700000000000000",
            eventName: "event",
            systemProps: makeEnvironment().systemProps,
            props: [:]
        )
    }
}
