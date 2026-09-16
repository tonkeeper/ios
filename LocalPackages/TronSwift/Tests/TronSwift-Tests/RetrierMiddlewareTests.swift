import Foundation
import Testing
@testable import TronSwiftAPI

struct RetrierMiddlewareTests {
    /// TK-2647: with an explicit request timeout a slow node fails in transport rather than with a
    /// status code, so pre-broadcast steps have to survive it the same way they survive a 503.
    @Test
    func transportFailure_isRetried() async throws {
        let attempts = Counter()

        let payload = try await middleware().execute(
            request: makeRequest(endpoint: "wallet/triggersmartcontract")
        ) {
            attempts.increment()
            if attempts.value < 2 {
                throw TronApi.Error.networkError
            }
            return makeSuccessPayload()
        }

        #expect(attempts.value == 2)
        #expect((payload.response as? HTTPURLResponse)?.statusCode == 200)
    }

    @Test
    func transportFailure_onBroadcast_isPropagated() async {
        let attempts = Counter()

        let error = await #expect(throws: TronApi.Error.self) {
            try await middleware().execute(
                request: makeRequest(endpoint: "wallet/broadcasthex")
            ) {
                attempts.increment()
                throw TronApi.Error.networkError
            }
        }

        guard case .networkError = error else {
            Issue.record("Expected networkError, got \(String(describing: error))")
            return
        }
        #expect(attempts.value == 1)
    }

    @Test
    func transportFailure_isPropagatedOnceRetriesRunOut() async {
        let attempts = Counter()

        let error = await #expect(throws: TronApi.Error.self) {
            try await middleware(maxRetriesCount: 1).execute(
                request: makeRequest(endpoint: "wallet/getsignweight")
            ) {
                attempts.increment()
                throw TronApi.Error.networkError
            }
        }

        guard case .networkError = error else {
            Issue.record("Expected networkError, got \(String(describing: error))")
            return
        }
        #expect(attempts.value == 2)
    }

    @Test
    func cancelledRequest_isNotRetried() async {
        let attempts = Counter()
        let middleware = middleware()
        let request = makeRequest(endpoint: "wallet/triggersmartcontract")

        let task = Task {
            try await middleware.execute(request: request) {
                attempts.increment()
                throw CancellationError()
            }
        }
        task.cancel()
        let result = await task.result

        #expect(throws: (any Error).self) { try result.get() }
        #expect(attempts.value == 1)
    }

    @Test
    func rateLimitedResponse_isRetriedUntilSuccess() async throws {
        let responses = ResponseScript(statusCodes: [429, 200])

        let payload = try await middleware().execute(
            request: makeRequest(endpoint: "wallet/getsignweight")
        ) {
            await responses.next()
        }

        #expect((payload.response as? HTTPURLResponse)?.statusCode == 200)
        #expect(await responses.callCount == 2)
    }

    @Test
    func rateLimitedResponse_isReturnedOnceRetriesRunOut() async throws {
        let responses = ResponseScript(statusCodes: [429, 429, 429, 429])

        let payload = try await middleware().execute(
            request: makeRequest(endpoint: "wallet/getsignweight")
        ) {
            await responses.next()
        }

        #expect((payload.response as? HTTPURLResponse)?.statusCode == 429)
        #expect(await responses.callCount == 3)
    }
}

private extension RetrierMiddlewareTests {
    final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        var value: Int {
            lock.lock()
            defer { lock.unlock() }
            return count
        }

        func increment() {
            lock.lock()
            defer { lock.unlock() }
            count += 1
        }
    }

    func middleware(maxRetriesCount: Int = 2) -> RetrierMiddleware {
        RetrierMiddleware(
            rateLimitRetryHandler: RequestRetrier(maxRetriesCount: maxRetriesCount, maxCooldown: 0)
        )
    }

    func makeRequest(endpoint: String) -> URLRequest {
        URLRequest(url: URL(string: "https://api.trongrid.io/\(endpoint)")!)
    }

    func makeSuccessPayload() -> HttpApiTransportPayload {
        HttpApiTransportPayload(
            data: Data(),
            response: HTTPURLResponse(
                url: URL(string: "https://api.trongrid.io")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }
}

private actor ResponseScript {
    private let statusCodes: [Int]
    private(set) var callCount = 0

    init(statusCodes: [Int]) {
        self.statusCodes = statusCodes
    }

    func next() -> HttpApiTransportPayload {
        let statusCode = statusCodes[min(callCount, statusCodes.count - 1)]
        callCount += 1
        return HttpApiTransportPayload(
            data: Data(),
            response: HTTPURLResponse(
                url: URL(string: "https://api.trongrid.io/wallet/getsignweight")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }
}
