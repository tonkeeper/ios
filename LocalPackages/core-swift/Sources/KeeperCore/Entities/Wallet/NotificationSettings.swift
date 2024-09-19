import Foundation

public struct NotificationSettings: Equatable {
  public let isOn: Bool
}

extension NotificationSettings: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.isOn = try container.decodeIfPresent(Bool.self, forKey: .isOn) ?? false
  }
}
