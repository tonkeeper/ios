import UIKit

enum CollectiblesList {
    enum SnapshotSection: Hashable {
        case all
        case empty
    }

    enum SnapshotItem: Hashable {
        case nft(identifier: String)
        case empty
    }

    typealias DataSource = UICollectionViewDiffableDataSource<SnapshotSection, SnapshotItem>
    typealias Snapshot = NSDiffableDataSourceSnapshot<SnapshotSection, SnapshotItem>
}
