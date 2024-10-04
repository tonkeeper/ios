import Foundation

/// Shared security settings for all wallets in the app
public struct SecuritySettings: Equatable {
  public let isBiometryEnabled: Bool
  public let isLockScreen: Bool
}

extension SecuritySettings: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.isBiometryEnabled = (try? container.decode(Bool.self, forKey: .isBiometryEnabled)) ?? false
    self.isLockScreen = (try? container.decode(Bool.self, forKey: .isLockScreen)) ?? false
  }
}
