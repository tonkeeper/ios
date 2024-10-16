import Foundation

public extension KeeperInfo {
  struct AppSettings: Equatable {
    public let isSecureMode: Bool
  }
}

extension KeeperInfo.AppSettings: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.isSecureMode = (try? container.decode(Bool.self, forKey: .isSecureMode)) ?? false
  }
}
