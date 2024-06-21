import Foundation

/// Shared security settings for all wallets in the app
struct SecuritySettings: Equatable {
  let isBiometryEnabled: Bool
}

extension SecuritySettings: Codable {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.isBiometryEnabled = (try? container.decode(Bool.self, forKey: .isBiometryEnabled)) ?? false
  }
}
