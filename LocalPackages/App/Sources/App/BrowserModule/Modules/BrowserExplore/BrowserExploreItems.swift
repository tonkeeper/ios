import UIKit

enum BrowserExplore {
  enum Section: Hashable {
    case empty
    case apps(id: String, header: AppsSectionHeader?, isMultilineAppsTitle: Bool)
    case featured
    
    static func ==(lhs: Section, rhs: Section) -> Bool {
      switch (lhs, rhs) {
      case (.empty, .empty):
        return true
      case (let .apps(lid, _, _), let .apps(rid, _, _)):
        return lid == rid
      case (.featured, .featured):
        return true
      default:
        return false
      }
    }
    
    func hash(into hasher: inout Hasher) {
      switch self {
      case .empty:
        hasher.combine("empty")
      case .apps(let id, _, _):
        hasher.combine(id)
      case .featured:
        hasher.combine("featured")
      }
    }
  }
  
  enum Item: Hashable {
    case empty
    case app(Browser.AppItem)
    case featured
  }
  
  struct AppsSectionHeader {
    let title: String
    let hasAll: Bool
    let allTapHandler: (() -> Void)?
  }
  
  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
}
