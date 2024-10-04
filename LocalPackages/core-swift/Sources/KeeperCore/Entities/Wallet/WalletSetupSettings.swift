import Foundation

public struct WalletSetupSettings: Codable, Equatable {
  public let backupDate: Date?
  
  public init(backupDate: Date?) {
    self.backupDate = backupDate
  }
}
