import Foundation
import TKLocalize
import LocalAuthentication
import KeeperCore

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
    case biometryNotEnrolled
    case biometryLockout
    case unknown
    
    init(nsError: NSError) {
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
        self = .biometryNotAvailable
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
    case .success(let state):
      switch state {
      case .faceID, .touchID: return true
      case .none: return false
      }
    }
  }
  
  func getBiometryState(policy: LAPolicy) -> Result<BiometryState, Error> {
    var error: NSError?
    guard context.canEvaluatePolicy(policy, error: &error) else {
      guard let error = error else {
        return .success(.none)
      }
      return .failure(Error(nsError: error))
    }
    
    return .success(BiometryState(type: context.biometryType))
  }
}
