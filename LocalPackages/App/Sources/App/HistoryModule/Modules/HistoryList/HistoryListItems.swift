import Foundation
import UIKit
import KeeperCore

enum HistoryList {
  typealias EventID = String
  
  struct Section {
    typealias ID = Date
    var date: Date { id }
    let id: ID
    let events: [AccountEvent]
  }

  enum SnapshotSection: Hashable {
    case events(Section.ID)
    case pagination
    case shimmer
  }

  enum SnapshotItem: Hashable {
    case event(EventID)
    case pagination
    case shimmer
  }

  typealias DataSource = UICollectionViewDiffableDataSource<SnapshotSection, SnapshotItem>
  typealias Snapshot = NSDiffableDataSourceSnapshot<SnapshotSection, SnapshotItem>
}

