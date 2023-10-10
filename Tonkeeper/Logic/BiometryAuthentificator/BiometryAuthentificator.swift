//
//  BiometryAuthentificator.swift
//  Tonkeeper
//
//  Created by Grigory on 4.10.23..
//

import Foundation
import LocalAuthentication

final class BiometryAuthentificator {
  enum BiometryType {
    case none
    case touchID
    case faceID
    case unknown
    
    init(type: LABiometryType) {
      switch type {
      case .none:
        self = .none
      case .touchID:
        self = .touchID
      case .faceID:
        self = .faceID
      default:
        self = .unknown
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
  
  struct BiometryResult {
    let type: BiometryType
    let isSuccess: Bool
  }
  
  private let context = LAContext()
  
  var biometryType: BiometryType {
    .init(type: context.biometryType)
  }
  
  func canEvaluate(policy: LAPolicy) -> Result<BiometryResult, Error> {
    var error: NSError?
    guard context.canEvaluatePolicy(policy, error: &error) else {
      guard let error = error else {
        return .success(.init(type: .init(type: context.biometryType), isSuccess: false))
      }
      return .failure(Error(nsError: error))
    }
    
    return .success(.init(type: .init(type: context.biometryType), isSuccess: true))
  }
  
  func evaluate(policy: LAPolicy) async -> Result<Bool, Error> {
    do {
      try await context.evaluatePolicy(policy, localizedReason: "Enter passcode")
      let result = try await context.evaluatePolicy(policy, localizedReason: "Enter passcode")
      return .success(result)
    } catch {
      return .failure(Error(nsError: error as NSError))
    }
  }
}
