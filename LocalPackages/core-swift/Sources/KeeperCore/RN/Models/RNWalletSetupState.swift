import Foundation

public struct RNWalletSetupState: Codable {
  public let lastBackupAt: TimeInterval?
  public let setupDismissed: Bool
  public let hasOpenedTelegramChannel: Bool
}
