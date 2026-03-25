import Foundation
import KeeperCore
import UIKit

enum HistoryList {
    typealias EventID = String

    struct Section {
        typealias ID = Date
        var date: Date {
            id
        }

        let id: ID
        let events: [HistoryEvent]
    }

    enum SnapshotSection: Hashable {
        case events(Section.ID)
        case pagination
        case shimmer
        case empty
    }

    enum SnapshotItem: Hashable {
        case event(EventID)
        case pagination
        case shimmer
        case empty
    }

    typealias DataSource = UICollectionViewDiffableDataSource<SnapshotSection, SnapshotItem>
    typealias Snapshot = NSDiffableDataSourceSnapshot<SnapshotSection, SnapshotItem>

    enum State {
        case loading
        case empty
        case content
    }

    enum Filter {
        case none
        case all
        case sent
        case received
        case spam
    }
}
