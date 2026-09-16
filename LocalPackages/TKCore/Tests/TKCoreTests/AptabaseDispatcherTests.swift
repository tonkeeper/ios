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
        let dispatcher = try XCTUnwrap(AptabaseDispatcher(
            endpoint: "https://analytics.example.com",
            appKey: "A-SH-0000000000",
            environment: makeEnvironment(),
            session: session
        ))

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
}

private extension AptabaseDispatcherTests {
    func makeDispatcher(responses: [StubAptabaseURLSession.Response]) -> AptabaseDispatcher {
        AptabaseDispatcher(
            endpoint: "https://analytics.example.com",
            appKey: "A-SH-0000000000",
            environment: makeEnvironment(),
            session: StubAptabaseURLSession(responses: responses)
        )!
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
