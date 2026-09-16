import Foundation

/// Pure brute-force lockout policy for passcode input (TK-1472).
///
/// The first `initialAttempts` failures are free. Every failure after that locks the input; the lockout
/// duration is taken from the highest escalation `Step` whose threshold the cumulative failure count has
/// reached. Default config (cumulative failure count → lockout): 1–5 free, 6–10 → 30s, 11–15 → 2m,
/// 16–20 → 5m, 21–29 → 15m, 30+ → 60m.
struct PasscodeLockoutPolicy {
    /// One escalation step: at `threshold` cumulative failures the lockout becomes `duration`.
    struct Step {
        /// Minimum cumulative failures at which this duration takes effect.
        let threshold: Int
        let duration: TimeInterval
    }

    /// Failed attempts allowed with no lockout. The first lockout fires on attempt `initialAttempts + 1`.
    let initialAttempts: Int
    /// Escalation steps, ascending by `threshold`. The highest step whose threshold ≤ the failure count wins.
    let steps: [Step]

    static let `default` = PasscodeLockoutPolicy(
        initialAttempts: 5,
        steps: [
            Step(threshold: 6, duration: 30),
            Step(threshold: 11, duration: 2 * 60),
            Step(threshold: 16, duration: 5 * 60),
            Step(threshold: 21, duration: 15 * 60),
            Step(threshold: 30, duration: 60 * 60),
        ]
    )

    /// Lockout duration for the given cumulative failure count. `0` while still inside the free window.
    func lockoutDuration(forFailedAttempts failedAttempts: Int) -> TimeInterval {
        guard failedAttempts > initialAttempts else { return 0 }
        var duration: TimeInterval = 0
        for step in steps where failedAttempts >= step.threshold {
            duration = step.duration
        }
        return duration
    }

    /// Longest lockout the policy can impose. Used to bound a stored end date against a backward clock jump.
    var maxLockoutDuration: TimeInterval {
        steps.map(\.duration).max() ?? 0
    }
}
