import Foundation
import KeeperCore

public struct HistoryAccountEventRightTopDescriptionProvider: AccountEventRightTopDescriptionProvider {
  private let dateFormatter: DateFormatter

  public init(dateFormatter: DateFormatter) {
    self.dateFormatter = dateFormatter
  }
  
  public mutating func rightTopDescription(accountEvent: AccountEvent,
                                           action: AccountEventAction) -> String? {
    return dateFormatter.string(from: accountEvent.date)
  }
}
