import Foundation

struct RequestRetrier {
    var maxRetriesCount: Int
    var maxCooldown: TimeInterval

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
        response: HTTPURLResponse,
        data: Data,
        attempt: Int
    ) -> Decision {
        guard response.statusCode == 429 else {
            return .succeeded
        }
        guard attempt < maxRetriesCount else {
            return .outOfAttempts
        }
        let cooldown = {
            let power = Double(max(attempt, 0))
            let base = pow(2.0, power)
            return min(base, maxCooldown)
        }()
        return .retry(cooldown: cooldown)
    }
}
