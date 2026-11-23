import Foundation
import KeeperCore
import LocalAuthentication
import TKLocalize
import TKLogging

final class BiometryProvider {
    enum BiometryState {
        case none
        case touchID
        case faceID

        init(type: LABiometryType) {
            switch type {
            case .none:
                self = .none
            case .touchID:
                self = .touchID
            case .faceID:
                self = .faceID
            default:
                self = .none
            }
        }
    }

    enum Error: Swift.Error {
        case authenticationFailed
        case userCancel
        case userFallback
        case passcodeNotSet
        case biometryNotAvailable
        /// Face ID is the only biometry an app asks the user to allow. A declined permission comes
        /// back as `biometryNotAvailable`, so a Face ID the device can't use reads the same; only
        /// the app's page in the Settings app allows a declined one again.
        case faceIDDenied
        case biometryNotEnrolled
        case biometryLockout
        case unknown

        init(nsError: NSError, biometryType: LABiometryType) {
            switch nsError {
            case LAError.authenticationFailed:
                self = .authenticationFailed
            case LAError.userCancel:
                self = .userCancel
            case LAError.userFallback:
                self = .userFallback
            case LAError.passcodeNotSet:
                self = .passcodeNotSet
            case LAError.biometryNotAvailable:
                self = biometryType == .faceID ? .faceIDDenied : .biometryNotAvailable
            case LAError.biometryNotEnrolled:
                self = .biometryNotEnrolled
            case LAError.biometryLockout:
                self = .biometryLockout
            default:
                self = .unknown
            }
        }
    }

    private let context = LAContext()

    var isAvailable: Bool {
        switch getBiometryState(policy: .deviceOwnerAuthenticationWithBiometrics) {
        case .failure: return false
        case let .success(state):
            switch state {
            case .faceID, .touchID: return true
            case .none: return false
            }
        }
    }

    var isFaceIDDenied: Bool {
        guard case .failure(.faceIDDenied) = getBiometryState(policy: .deviceOwnerAuthenticationWithBiometrics) else {
            return false
        }
        return true
    }

    func getBiometryState(policy: LAPolicy) -> Result<BiometryState, Error> {
        var error: NSError?
        guard context.canEvaluatePolicy(policy, error: &error) else {
            guard let error = error else {
                return .success(.none)
            }
            return .failure(Error(nsError: error, biometryType: context.biometryType))
        }

        return .success(BiometryState(type: context.biometryType))
    }
}
