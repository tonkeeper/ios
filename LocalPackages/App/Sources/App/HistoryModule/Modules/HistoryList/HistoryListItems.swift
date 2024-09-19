import Foundation

enum HistoryListSection: Hashable {
  case events(HistoryListEventsSection)
  case pagination
  case shimmer
}

struct HistoryListEventsSection: Hashable {
  let date: Date
  let title: String?
}

enum HistoryListItem: Hashable {
  case event(identifier: String)
  case pagination
  case shimmer
}
