@testable import App
import Foundation
import Security
import XCTest

final class BiometryFailureClassifierTests: XCTestCase {
    func test_userCanceled_isCanceled() {
        XCTAssertEqual(classify(status: errSecUserCanceled), .canceled)
    }

    func test_authFailed_whenBiometryUnusableAndLockedOut_isLockout() {
        let result = classify(
            status: errSecAuthFailed,
            canEvaluateBiometrics: false,
            isLockout: true
        )
        XCTAssertEqual(result, .lockout)
    }

    func test_authFailed_whenBiometryUnusableAndNotLockedOut_isInvalidated() {
        // Biometry can no longer be evaluated and it is not lockout: the
        // enrollment was removed, so the access control is invalidated.
        let result = classify(
            status: errSecAuthFailed,
            canEvaluateBiometrics: false,
            isLockout: false
        )
        XCTAssertEqual(result, .invalidated)
    }

    func test_authFailed_whenBiometryUsableAndProbeSatisfiable_isFailedAttempt() {
        // The reported bug: a plain failed Face ID / Touch ID with the item still
        // satisfiable must NOT be treated as an enrollment change.
        let result = classify(
            status: errSecAuthFailed,
            canEvaluateBiometrics: true,
            accessProbe: .satisfiable
        )
        XCTAssertEqual(result, .failedAttempt)
    }

    func test_authFailed_whenBiometryUsableAndProbeInvalidated_isInvalidated() {
        let result = classify(
            status: errSecAuthFailed,
            canEvaluateBiometrics: true,
            accessProbe: .invalidated
        )
        XCTAssertEqual(result, .invalidated)
    }

    func test_authFailed_whenBiometryUsableAndProbeIndeterminate_isFailedAttempt() {
        // Cannot prove a change, so do not raise the alert.
        let result = classify(
            status: errSecAuthFailed,
            canEvaluateBiometrics: true,
            accessProbe: .indeterminate
        )
        XCTAssertEqual(result, .failedAttempt)
    }

    func test_unrelatedStatus_isOther() {
        XCTAssertEqual(classify(status: errSecBadReq), .other)
    }

    func test_itemNotFound_whenProbeInvalidated_isInvalidated() {
        // On device an invalidated biometryCurrentSet item reads as not-found;
        // the probe (e.g. via the non-biometry wallet) proves it was present.
        let result = classify(
            status: errSecItemNotFound,
            canEvaluateBiometrics: true,
            accessProbe: .invalidated
        )
        XCTAssertEqual(result, .invalidated)
    }

    func test_itemNotFound_whenProbeNotInvalidated_isOther() {
        // Nothing proves the item ever existed, so there is nothing to recover.
        XCTAssertEqual(classify(status: errSecItemNotFound), .other)
    }
}

private extension BiometryFailureClassifierTests {
    func classify(
        status: OSStatus,
        canEvaluateBiometrics: Bool = false,
        isLockout: Bool = false,
        accessProbe: BiometryAccessProbe = .indeterminate
    ) -> BiometryUnlockFailure {
        classifyBiometryUnlockFailure(
            status: status,
            canEvaluateBiometrics: canEvaluateBiometrics,
            isLockout: isLockout,
            accessProbe: accessProbe
        )
    }
}
