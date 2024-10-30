import Foundation

public struct WalletSetupSettings: Codable, Equatable {
  public let backupDate: Date?
  public let isSetupFinished: Bool
  
  public init(backupDate: Date? = nil,
              isSetupFinished: Bool = false) {
    self.backupDate = backupDate
    self.isSetupFinished = isSetupFinished
  }
  
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.backupDate = try container.decodeIfPresent(Date.self, forKey: .backupDate)
    self.isSetupFinished = try container.decodeIfPresent(Bool.self, forKey: .isSetupFinished) ?? false
  }
}
