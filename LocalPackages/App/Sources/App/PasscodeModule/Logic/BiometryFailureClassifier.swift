import Foundation
import Security

/// Classification of why a biometric unlock attempt failed.
enum BiometryUnlockFailure: Equatable {
    /// User dismissed the biometric prompt.
    case canceled
    /// Biometry is locked out after too many failed attempts.
    case lockout
    /// The enrolled biometric set changed, so the access control can no longer
    /// be satisfied — the user must re-authenticate with the passcode.
    case invalidated
    /// A plain failed match (wrong finger / face not recognized) while the
    /// enrolled set is unchanged — no recovery needed.
    case failedAttempt
    /// Any other keychain failure unrelated to biometry.
    case other
}

/// Result of a non-interactive probe of the biometry-protected item. It tells an
/// invalidated access control apart from a plain failed match without relying on
/// `evaluatedPolicyDomainState` (nil on the Simulator and for users who enabled
/// biometry before the baseline snapshot existed).
enum BiometryAccessProbe: Equatable {
    /// Access control can still be satisfied — the item is present and a real
    /// unlock would prompt.
    case satisfiable
    /// Access control can no longer be satisfied — the enrolled set changed.
    case invalidated
    /// Could not determine (item missing or unexpected error). Be conservative.
    case indeterminate
}

/// `errSecAuthFailed` is overloaded: it covers an invalidated access control
/// (enrollment changed), biometry lockout, and a plain failed match. The status
/// alone can't tell them apart. A non-interactive probe of the item itself
/// (`BiometryAccessProbe`) disambiguates an invalidated set from a failed match,
/// because an invalidated `biometryCurrentSet` item reports `errSecAuthFailed`
/// even without prompting, while a still-valid item does not.
///
/// Kept free of `LAContext` / keychain so the decision is pure and testable.
func classifyBiometryUnlockFailure(
    status: OSStatus,
    canEvaluateBiometrics: Bool,
    isLockout: Bool,
    accessProbe: BiometryAccessProbe
) -> BiometryUnlockFailure {
    switch status {
    case errSecUserCanceled:
        return .canceled
    case errSecAuthFailed:
        guard canEvaluateBiometrics else {
            // Biometry unusable: lockout is recoverable by waiting, while a
            // missing enrollment means the access control is invalidated.
            return isLockout ? .lockout : .invalidated
        }
        // Biometry is usable, so the failure is either an invalidated set or a
        // plain failed match. The probe distinguishes them: only an invalidated
        // access control fails a non-interactive read.
        return accessProbe == .invalidated ? .invalidated : .failedAttempt
    case errSecItemNotFound:
        // On device a `biometryCurrentSet` item invalidated by an enrollment
        // change is reported as not-found, indistinguishable from a truly absent
        // item by status alone. The probe disambiguates it (e.g. via the
        // non-biometry wallet): treat it as invalidated only when the probe says
        // so, otherwise there is genuinely nothing to recover.
        return accessProbe == .invalidated ? .invalidated : .other
    default:
        return .other
    }
}
