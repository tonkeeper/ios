import Foundation

enum HistoryListSection: Hashable {
  case events(HistoryListEventsSection)
  case pagination
  case shimmer
}

struct HistoryListEventsSection: Hashable {
  let date: Date
}

enum HistoryListItem: Hashable {
  case event(identifier: String)
  case pagination
  case shimmer
}
