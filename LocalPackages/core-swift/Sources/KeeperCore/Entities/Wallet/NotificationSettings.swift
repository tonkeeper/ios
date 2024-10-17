import Foundation

public struct NotificationSettings: Equatable {
  public let isOn: Bool
  public let dapps: [String: Bool]
}

extension NotificationSettings: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.isOn = try container.decodeIfPresent(Bool.self, forKey: .isOn) ?? false
    self.dapps = try container.decodeIfPresent([String: Bool].self, forKey: .dapps) ?? [:]
  }
}
