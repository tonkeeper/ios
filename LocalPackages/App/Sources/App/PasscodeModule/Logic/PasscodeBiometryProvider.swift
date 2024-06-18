import Foundation
import TKUIKit
import KeeperCore

struct PasscodeBiometryProvider: PasscodeInputBiometryProvider {
  
  private let biometryProvider: BiometryProvider
  private let securityStore: SecurityStore
  
  init(biometryProvider: BiometryProvider,
       securityStore: SecurityStore) {
    self.biometryProvider = biometryProvider
    self.securityStore = securityStore
  }
  
  func getBiometryState() async -> TKUIKit.TKKeyboardView.Biometry {
    guard await securityStore.isBiometryEnabled else {
      return .none
    }
    switch biometryProvider.getBiometryState(policy: .deviceOwnerAuthenticationWithBiometrics) {
    case .failure:
      return .none
    case .success(let state):
      switch state {
      case .faceID: return .faceId
      case .touchID: return .touchId
      case .none: return .none
      }
    }
  }
}
