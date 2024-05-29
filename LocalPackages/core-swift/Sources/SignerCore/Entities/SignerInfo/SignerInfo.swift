import Foundation

/// Represents the entire state of the application install
public struct SignerInfo: Codable {
  let walletKeys: [WalletKey]
  
  /// Common pin/faceid settings
  let securitySettings: SecuritySettings
  
  let isSetupFinished: Bool
}
