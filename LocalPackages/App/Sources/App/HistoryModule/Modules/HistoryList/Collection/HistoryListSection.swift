import Foundation

enum HistoryListSection: Hashable {
  case events(HistoryListEventsSection)
//  case pagination
//  case shimmer(shimmers: [String])
//  
//  enum Pagination: Hashable {
//    case loading
//    case error(title: String?)
//    
//    func hash(into hasher: inout Hasher) {}
//  }
//  
//  struct EventsSectionData: Hashable {
//    let date: Date
//    let title: String?
//    let items: [String]
//    
//    func hash(into hasher: inout Hasher) {
//      hasher.combine(date)
//    }
//    
//    static func == (lhs: Self, rhs: Self) -> Bool {
//      lhs.hashValue == rhs.hashValue
//    }
//  }
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
