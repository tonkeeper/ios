import Foundation

struct RequestRetrier {
    var maxRetriesCount: Int
    var maxCooldown: TimeInterval

    /// A repeated broadcast can duplicate a transaction that did reach the chain, so its outcome is
    /// reported instead of retried.
    private static let nonRetryableEndpoints = [
        "wallet/broadcasthex",
    ]

    init(
        maxRetriesCount: Int = 2,
        maxCooldown: TimeInterval = 10
    ) {
        self.maxRetriesCount = max(maxRetriesCount, 0)
        self.maxCooldown = max(maxCooldown, 0)
    }
}

extension RequestRetrier {
    enum Decision {
        case succeeded
        case retry(cooldown: TimeInterval)
        case outOfAttempts
    }

    func makeDecision(
        request: URLRequest,
        response: HTTPURLResponse,
        data: Data,
        attempt: Int
    ) -> Decision {
        guard response.statusCode == 429 || response.statusCode >= 500 else {
            return .succeeded
        }
        // TronGrid "suspends" a method for a few seconds after a 429; 1-2s retries land
        // inside that window and fail again, so 429 pauses start from 3s. A cooldown the
        // server states — in the header or in the body — raises them further, never lowers
        // them: the 3s floor was measured, the announced rate was not reliable.
        var minCooldown: TimeInterval = 0
        if response.statusCode == 429 {
            let announced = TronRateLimitHint.cooldown(response: response, data: data) ?? 0
            minCooldown = max(3 * pow(2.0, Double(max(attempt, 0))), announced)
        }
        return retryDecision(request: request, attempt: attempt, minCooldown: minCooldown)
    }

    func retryDecision(request: URLRequest, attempt: Int, minCooldown: TimeInterval = 0) -> Decision {
        guard Self.isRetryable(request: request) else {
            return .succeeded
        }
        guard attempt < maxRetriesCount else {
            return .outOfAttempts
        }
        let cooldown = min(max(pow(2.0, Double(max(attempt, 0))), minCooldown), maxCooldown)
        return .retry(cooldown: cooldown)
    }

    static func isRetryable(request: URLRequest) -> Bool {
        guard let path = request.url?.path else {
            return true
        }
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return !nonRetryableEndpoints.contains { normalizedPath.hasSuffix($0) }
    }
}
