import Foundation

public struct TokenManagementState: Codable, Equatable {
  public let pinnedItems: [String]
  public let hiddenItems: [String]
}
