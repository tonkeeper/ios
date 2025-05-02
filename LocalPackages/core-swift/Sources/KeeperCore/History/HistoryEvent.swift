import Foundation

public enum HistoryEvent: Codable {
  case tonAccountEvent(AccountEvent)
  case tronEvent(TronTransaction)
  
  public var timestamp: Int64 {
    switch self {
    case .tonAccountEvent(let event):
      return Int64(event.date.timeIntervalSince1970)
    case .tronEvent(let event):
      return Int64(event.timestamp)
    }
  }
  
  public var date: Date {
    switch self {
    case .tonAccountEvent(let event):
      return event.date
    case .tronEvent(let event):
      return Date(timeIntervalSince1970: TimeInterval(event.timestamp))
    }
  }
  
  public var eventId: String {
    switch self {
    case .tonAccountEvent(let event):
      return event.eventId
    case .tronEvent(let event):
      return event.txID
    }
  }
  
  public var identifier: String {
    switch self {
    case .tonAccountEvent(let event):
      return "ton\(event.eventId)"
    case .tronEvent(let event):
      return "tron\(event.txID)"
    }
  }
  
  public var isScam: Bool {
    switch self {
    case .tonAccountEvent(let event):
      return event.isScam
    case .tronEvent:
      return false
    }
  }
}
