import Foundation

enum HistoryV2ListSection: Hashable {
  case events(HistoryV2ListEventsSection)
  case pagination
  case shimmer
}

struct HistoryV2ListEventsSection: Hashable {
  let date: Date
  let title: String?
}

enum HistoryV2ListItem: Hashable {
  case event(identifier: String)
  case pagination
  case shimmer
}
