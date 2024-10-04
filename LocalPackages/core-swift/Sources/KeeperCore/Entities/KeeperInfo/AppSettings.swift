import Foundation

public extension KeeperInfo {
  struct AppSettings: Equatable {
    public let isSetupFinished: Bool
    public let isSecureMode: Bool
  }
}

extension KeeperInfo.AppSettings: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.isSetupFinished = (try? container.decode(Bool.self, forKey: .isSetupFinished)) ?? false
    self.isSecureMode = (try? container.decode(Bool.self, forKey: .isSecureMode)) ?? false
  }
}
