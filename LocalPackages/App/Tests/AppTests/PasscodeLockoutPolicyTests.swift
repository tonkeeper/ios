@testable import App
import XCTest

final class PasscodeLockoutPolicyTests: XCTestCase {
    private let policy = PasscodeLockoutPolicy.default

    // MARK: - lockoutDuration: free window

    func test_lockoutDuration_freeWindow_isZero() {
        for failedAttempts in 0 ... 5 {
            XCTAssertEqual(
                policy.lockoutDuration(forFailedAttempts: failedAttempts), 0,
                "Attempts 1–5 are free (failedAttempts=\(failedAttempts))"
            )
        }
    }

    // MARK: - lockoutDuration: escalating steps (every failure past the window locks)

    func test_lockoutDuration_escalatesByStep() {
        XCTAssertEqual(policy.lockoutDuration(forFailedAttempts: 6), 30, "6–10 → 30s")
        XCTAssertEqual(policy.lockoutDuration(forFailedAttempts: 10), 30)
        XCTAssertEqual(policy.lockoutDuration(forFailedAttempts: 11), 2 * 60, "11–15 → 2m")
        XCTAssertEqual(policy.lockoutDuration(forFailedAttempts: 15), 2 * 60)
        XCTAssertEqual(policy.lockoutDuration(forFailedAttempts: 16), 5 * 60, "16–20 → 5m")
        XCTAssertEqual(policy.lockoutDuration(forFailedAttempts: 20), 5 * 60)
        XCTAssertEqual(policy.lockoutDuration(forFailedAttempts: 21), 15 * 60, "21–29 → 15m")
        XCTAssertEqual(policy.lockoutDuration(forFailedAttempts: 29), 15 * 60)
    }

    func test_lockoutDuration_capsAtLastStep() {
        XCTAssertEqual(policy.lockoutDuration(forFailedAttempts: 30), 60 * 60, "30+ → 60m")
        XCTAssertEqual(policy.lockoutDuration(forFailedAttempts: 31), 60 * 60)
        XCTAssertEqual(policy.lockoutDuration(forFailedAttempts: 100), 60 * 60)
    }

    // MARK: - maxLockoutDuration

    func test_maxLockoutDuration_isLongestStep() {
        XCTAssertEqual(policy.maxLockoutDuration, 60 * 60)
    }

    // MARK: - custom / degenerate configs (the policy is configurable)

    func test_customConfig_respectsParameters() {
        let custom = PasscodeLockoutPolicy(
            initialAttempts: 3,
            steps: [
                PasscodeLockoutPolicy.Step(threshold: 4, duration: 10),
                PasscodeLockoutPolicy.Step(threshold: 6, duration: 20),
            ]
        )
        XCTAssertEqual(custom.lockoutDuration(forFailedAttempts: 3), 0, "Within the free window")
        XCTAssertEqual(custom.lockoutDuration(forFailedAttempts: 4), 10)
        XCTAssertEqual(custom.lockoutDuration(forFailedAttempts: 5), 10)
        XCTAssertEqual(custom.lockoutDuration(forFailedAttempts: 6), 20)
        XCTAssertEqual(custom.lockoutDuration(forFailedAttempts: 9), 20, "Caps at the last step")
        XCTAssertEqual(custom.maxLockoutDuration, 20)
    }

    func test_noSteps_returnZero() {
        let empty = PasscodeLockoutPolicy(initialAttempts: 5, steps: [])
        XCTAssertEqual(empty.lockoutDuration(forFailedAttempts: 6), 0)
        XCTAssertEqual(empty.maxLockoutDuration, 0)
    }
}
