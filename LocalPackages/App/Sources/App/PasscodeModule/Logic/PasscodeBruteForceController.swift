import Foundation
import KeeperCore
import TKCore

/// Outcome of recording a failed passcode attempt.
struct PasscodeFailureOutcome {
    /// Attempts remaining before the lockout, or `nil` when the counter should stay hidden.
    let attemptsLeft: Int?
    /// End date of the lockout triggered by this failure, or `nil` if no lockout was triggered.
    let lockoutEndDate: Date?
}

/// Coordinates passcode brute-force protection: persisted attempt counting, escalating lockouts and
/// analytics. Shared across every passcode prompt (app unlock + in-app confirmations) so the counter
/// is global to the single app passcode. See TK-1472.
protocol PasscodeBruteForceProtection: AnyObject {
    /// End date of an active lockout, or `nil` if input is currently allowed.
    func activeLockoutEndDate() -> Date?
    /// Resets the failure counter and clears any lockout. Call on a successful unlock.
    func registerSuccess() async
    /// Records a failed attempt, persisting the new count and any triggered lockout.
    func registerFailure() async -> PasscodeFailureOutcome
}

/// Persistence seam for brute-force state. Lets the controller be unit-tested against an in-memory fake
/// instead of the concrete `SecurityStore`. Production conformance is on `SecurityStore` below.
protocol PasscodeBruteForceStore: AnyObject {
    func bruteForceState() -> (failedAttempts: Int, lockoutEndDate: Date?)
    func setBruteForce(failedAttempts: Int, lockoutEndDate: Date?) async
}

/// Analytics seam, narrow enough to fake in tests. The concrete `AnalyticsProvider` (a struct) conforms below.
/// `from` is the generated analytics enum — the contract itself — so there is no hand-written mirror to keep in
/// sync: `.unlock` = app-unlock prompt, `.confirmation` = in-app action confirmation, `.change` = the "enter
/// current passcode" step of change-passcode.
protocol PasscodeLockoutAnalytics {
    func logPasscodeLockout(from: PasscodeLockout.From, durationSeconds: Int, failedAttempts: Int)
}

final class PasscodeBruteForceController: PasscodeBruteForceProtection {
    private let store: PasscodeBruteForceStore
    private let analytics: PasscodeLockoutAnalytics?
    private let from: PasscodeLockout.From
    private let policy: PasscodeLockoutPolicy
    private let now: () -> Date

    init(
        store: PasscodeBruteForceStore,
        analytics: PasscodeLockoutAnalytics?,
        from: PasscodeLockout.From,
        policy: PasscodeLockoutPolicy = .default,
        now: @escaping () -> Date = { Date() }
    ) {
        self.store = store
        self.analytics = analytics
        self.from = from
        self.policy = policy
        self.now = now
    }

    /// Production wiring against the concrete dependencies.
    convenience init(
        securityStore: SecurityStore,
        analyticsProvider: AnalyticsProvider?,
        from: PasscodeLockout.From,
        policy: PasscodeLockoutPolicy = .default
    ) {
        self.init(store: securityStore, analytics: analyticsProvider, from: from, policy: policy)
    }

    func activeLockoutEndDate() -> Date? {
        let now = now()
        guard let endDate = store.bruteForceState().lockoutEndDate, endDate > now else { return nil }
        // `Date` is already absolute, so timezone changes / travel don't matter. But a manual device-clock
        // change or NTP correction jumping the wall clock *backward* could leave `endDate` arbitrarily far in
        // the future and strand the user. Bound the wait to the longest policy lockout so it self-heals.
        // (A *forward* clock change still skips the wait — unfixable at app level without a secure counter.)
        return min(endDate, now.addingTimeInterval(policy.maxLockoutDuration))
    }

    func registerSuccess() async {
        let state = store.bruteForceState()
        guard state.failedAttempts != 0 || state.lockoutEndDate != nil else { return }
        await store.setBruteForce(failedAttempts: 0, lockoutEndDate: nil)
    }

    func registerFailure() async -> PasscodeFailureOutcome {
        let failedAttempts = store.bruteForceState().failedAttempts + 1

        // Free window is the first `initialAttempts` failures; every failure after that locks.
        var lockoutEndDate: Date?
        if failedAttempts > policy.initialAttempts {
            let duration = policy.lockoutDuration(forFailedAttempts: failedAttempts)
            lockoutEndDate = now().addingTimeInterval(duration)
            analytics?.logPasscodeLockout(from: from, durationSeconds: Int(duration), failedAttempts: failedAttempts)
        }

        await store.setBruteForce(failedAttempts: failedAttempts, lockoutEndDate: lockoutEndDate)

        // "N attempts left" counts down to the first lockout, which fires on attempt `initialAttempts + 1`.
        // So the last free attempt reads "1 attempt left" and the next wrong entry locks. Show only the
        // final two (2 → 1); hide earlier (too noisy) and once locked (the lockout itself is the signal).
        let attemptsBeforeLockout = policy.initialAttempts + 1 - failedAttempts
        return PasscodeFailureOutcome(
            attemptsLeft: (1 ... 2).contains(attemptsBeforeLockout) ? attemptsBeforeLockout : nil,
            lockoutEndDate: lockoutEndDate
        )
    }
}

extension SecurityStore: PasscodeBruteForceStore {
    func bruteForceState() -> (failedAttempts: Int, lockoutEndDate: Date?) {
        let state = getState()
        return (state.failedPasscodeAttempts, state.passcodeLockoutEndDate)
    }

    func setBruteForce(failedAttempts: Int, lockoutEndDate: Date?) async {
        await setPasscodeBruteForce(failedAttempts: failedAttempts, lockoutEndDate: lockoutEndDate)
    }
}

extension AnalyticsProvider: PasscodeLockoutAnalytics {
    func logPasscodeLockout(from: PasscodeLockout.From, durationSeconds: Int, failedAttempts: Int) {
        log(
            PasscodeLockout(
                from: from,
                lockoutSeconds: durationSeconds,
                failedAttempts: failedAttempts
            )
        )
    }
}
