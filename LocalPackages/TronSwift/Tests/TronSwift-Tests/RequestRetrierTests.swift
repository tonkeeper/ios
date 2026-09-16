import Foundation
import Testing
@testable import TronSwiftAPI

struct RequestRetrierTests {
    private let retrier = RequestRetrier()

    /// Measured on TronGrid: the method stays suspended for a few seconds after a 429,
    /// so 429 cooldowns start from 3s instead of the plain exponential 1s/2s.
    @Test
    func rateLimitedRequest_isRetriedWithGrowingCooldown() {
        guard case let .retry(first) = decision(statusCode: 429, attempt: 0),
              case let .retry(second) = decision(statusCode: 429, attempt: 1)
        else {
            Issue.record("Expected retries for 429")
            return
        }
        #expect(first == 3)
        #expect(second == 6)
    }

    @Test
    func rateLimitCooldownHonorsRetryAfter() {
        guard case let .retry(cooldown) = retrier.makeDecision(
            request: makeRequest(endpoint: "wallet/getsignweight"),
            response: makeResponse(statusCode: 429, headers: ["Retry-After": "7"]),
            data: Data(),
            attempt: 0
        ) else {
            Issue.record("Expected a retry")
            return
        }
        #expect(cooldown == 7)
    }

    /// TronGrid usually announces the suspension in the body rather than the header.
    @Test
    func rateLimitCooldownHonorsSuspensionAnnouncedInTheBody() {
        guard case let .retry(cooldown) = retrier.makeDecision(
            request: makeRequest(endpoint: "wallet/getsignweight"),
            response: makeResponse(statusCode: 429),
            data: Data("the request rate of (getsignweight) has been suspended for 8 s".utf8),
            attempt: 0
        ) else {
            Issue.record("Expected a retry")
            return
        }
        #expect(cooldown == 8)
    }

    /// The measured 3s floor stands even when the server announces less: a shorter pause was
    /// observed landing back inside the suspension.
    @Test
    func announcedCooldownDoesNotLowerTheMeasuredFloor() {
        guard case let .retry(cooldown) = retrier.makeDecision(
            request: makeRequest(endpoint: "wallet/getsignweight"),
            response: makeResponse(statusCode: 429),
            data: Data("suspended for 1 s".utf8),
            attempt: 0
        ) else {
            Issue.record("Expected a retry")
            return
        }
        #expect(cooldown == 3)
    }

    @Test
    func serverErrorBodyIsNotReadForACooldown() {
        guard case let .retry(cooldown) = retrier.makeDecision(
            request: makeRequest(endpoint: "wallet/getsignweight"),
            response: makeResponse(statusCode: 503),
            data: Data("suspended for 8 s".utf8),
            attempt: 0
        ) else {
            Issue.record("Expected a retry")
            return
        }
        #expect(cooldown == 1)
    }

    /// TK-2647: an overloaded TronGrid node used to fail the send outright; a repeat usually works.
    @Test
    func serverErrors_areRetried() {
        guard case .retry = decision(statusCode: 503, attempt: 0) else {
            Issue.record("Expected 503 to be retried")
            return
        }
        guard case .retry = decision(statusCode: 500, attempt: 0) else {
            Issue.record("Expected 500 to be retried")
            return
        }
    }

    @Test
    func clientErrors_areNotRetried() {
        guard case .succeeded = decision(statusCode: 400, attempt: 0) else {
            Issue.record("Expected 400 to be reported as is")
            return
        }
        guard case .succeeded = decision(statusCode: 403, attempt: 0) else {
            Issue.record("Expected 403 to be reported as is")
            return
        }
    }

    @Test
    func retriesStopAfterBudgetIsSpent() {
        guard case .outOfAttempts = decision(statusCode: 429, attempt: 2) else {
            Issue.record("Expected the retry budget to be exhausted")
            return
        }
    }

    /// Repeating a broadcast whose outcome is unknown is the caller's decision, not the transport's.
    @Test
    func broadcastIsNeverRetried() {
        guard case .succeeded = decision(
            statusCode: 503,
            attempt: 0,
            endpoint: "wallet/broadcasthex"
        ) else {
            Issue.record("Expected broadcast to be reported as is")
            return
        }
    }

    @Test
    func transportFailuresAreRetriedExceptOnBroadcast() {
        guard case .retry = retrier.retryDecision(
            request: makeRequest(endpoint: "wallet/triggersmartcontract"),
            attempt: 0
        ) else {
            Issue.record("Expected a transport failure to be retried")
            return
        }
        guard case .succeeded = retrier.retryDecision(
            request: makeRequest(endpoint: "wallet/broadcasthex"),
            attempt: 0
        ) else {
            Issue.record("Expected broadcast to be reported as is")
            return
        }
        guard case .outOfAttempts = retrier.retryDecision(
            request: makeRequest(endpoint: "wallet/triggersmartcontract"),
            attempt: 2
        ) else {
            Issue.record("Expected the retry budget to be exhausted")
            return
        }
    }

    @Test
    func cooldownIsCapped() {
        let retrier = RequestRetrier(maxRetriesCount: 10, maxCooldown: 3)

        guard case let .retry(cooldown) = retrier.makeDecision(
            request: makeRequest(endpoint: "wallet/getsignweight"),
            response: makeResponse(statusCode: 429),
            data: Data(),
            attempt: 5
        ) else {
            Issue.record("Expected a retry")
            return
        }
        #expect(cooldown == 3)
    }
}

private extension RequestRetrierTests {
    func decision(
        statusCode: Int,
        attempt: Int,
        endpoint: String = "wallet/triggersmartcontract"
    ) -> RequestRetrier.Decision {
        retrier.makeDecision(
            request: makeRequest(endpoint: endpoint),
            response: makeResponse(statusCode: statusCode),
            data: Data(),
            attempt: attempt
        )
    }

    func makeRequest(endpoint: String) -> URLRequest {
        URLRequest(url: URL(string: "https://api.trongrid.io/\(endpoint)")!)
    }

    func makeResponse(statusCode: Int, headers: [String: String]? = nil) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.trongrid.io")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headers
        )!
    }
}
