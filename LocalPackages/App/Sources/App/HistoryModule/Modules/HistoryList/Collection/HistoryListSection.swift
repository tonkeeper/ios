import Foundation

enum HistoryListSection: Hashable {
  case events(HistoryListEventsSection)
  case pagination(Pagination)
//  case shimmer(shimmers: [String])
  
  enum Pagination: Hashable {
    case loading
    case error(title: String?)
    
    func hash(into hasher: inout Hasher) {}
  }
}

struct HistoryListEventsSection: Hashable {
  let date: Date
  let title: String?
  let events: [HistoryEventCell.Model]
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(date)
  }
  
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.hashValue == rhs.hashValue
  }
}
