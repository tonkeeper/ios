import TKUIKit
import UIKit

enum BrowserExplore {
    enum Section: Hashable {
        case apps(id: String, header: AppsSectionHeader?, twoLinesAppsTitle: Bool)
        case featured
        case ads

        static func == (lhs: Section, rhs: Section) -> Bool {
            switch (lhs, rhs) {
            case let (.apps(lid, _, _), .apps(rid, _, _)):
                return lid == rid
            case (.featured, .featured):
                return true
            case (.ads, .ads):
                return true
            default:
                return false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case let .apps(id, _, _):
                hasher.combine(id)
            case .featured:
                hasher.combine("featured")
            case .ads:
                hasher.combine("ads")
            }
        }
    }

    enum Item: Hashable {
        case app(Browser.AppItem)
        case featured
        case ads(AdsItem)
    }

    struct AppsSectionHeader {
        let title: String
        let hasAll: Bool
        let allTapHandler: (() -> Void)?
    }

    struct AdsItem: Hashable {
        let identifier: String
        let configuration: TKListItemCell.Configuration
        let buttonAccessory: TKListItemButtonAccessoryView.Configuration?

        static func == (lhs: AdsItem, rhs: AdsItem) -> Bool {
            lhs.identifier == rhs.identifier
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(identifier)
        }
    }

    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
}
