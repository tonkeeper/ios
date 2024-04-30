import Foundation

public struct WalletBalanceSetupModel {
  public struct Biometry {
    public let isBiometryEnabled: Bool
    public let isRequired: Bool
    
    public init(isBiometryEnabled: Bool, isRequired: Bool) {
      self.isBiometryEnabled = isBiometryEnabled
      self.isRequired = isRequired
    }
  }
  public let didBackup: Bool
  public let biometry: Biometry
  public let isFinishSetupAvailable: Bool
}
