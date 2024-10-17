import Foundation

public struct TokenManagementState: Codable {
  public let pinnedItems: [String]
  public let hiddenState: [String: Bool]
}
