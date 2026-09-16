import Foundation

/// tonapi answers a 429 with a bare `{"error":"rate limit: limit for ip"}` and no `Retry-After`,
/// so the pause is ours to pick: exponential with jitter, capped.
enum TonAPIRateLimitBackoff {
    static let maxRetryCount = 5
    static let minDelayNanoseconds: UInt64 = 100_000_000
    static let maxDelayNanoseconds: UInt64 = 32_000_000_000
    static let multiplier = 2.0
    static let jitterFraction = 0.25

    static func delayNanoseconds(
        attempt: Int,
        jitter: Double = Double.random(in: -jitterFraction ... jitterFraction)
    ) -> UInt64 {
        let clampedJitter = min(max(jitter, -jitterFraction), jitterFraction)
        let base = Double(minDelayNanoseconds) * pow(multiplier, Double(max(attempt, 0)))
        let capped = min(base, Double(maxDelayNanoseconds))
        return UInt64(max(0, capped * (1 + clampedJitter)))
    }
}
