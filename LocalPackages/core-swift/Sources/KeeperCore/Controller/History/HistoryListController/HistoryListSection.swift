import Foundation

public struct HistoryListSection {
  public let date: Date
  public let title: String?
  public var events: [AccountEventModel]
}
