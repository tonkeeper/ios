import Foundation

public final class SettingsSecurityController {
  
  private let securityStore: SecurityStore
  
  init(securityStore: SecurityStore) {
    self.securityStore = securityStore
  }
  
  public var isBiometryEnabled: Bool {
    get async {
      await securityStore.isBiometryEnabled
    }
  }
  
  public func setIsBiometryEnabled(_ isBiometryEnabled: Bool) async -> Bool {
    do {
      try await securityStore.setIsBiometryEnabled(isBiometryEnabled)
      return isBiometryEnabled
    } catch {
      return !isBiometryEnabled
    }
  }
}
