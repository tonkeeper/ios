import UIKit
import TKUIKit

enum BrowserExplore {
  enum Section: Hashable {
    case empty
    case apps(id: String, header: AppsSectionHeader?, isMultilineAppsTitle: Bool)
    case featured
    case ads
    
    static func ==(lhs: Section, rhs: Section) -> Bool {
      switch (lhs, rhs) {
      case (.empty, .empty):
        return true
      case (let .apps(lid, _, _), let .apps(rid, _, _)):
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
      case .empty:
        hasher.combine("empty")
      case .apps(let id, _, _):
        hasher.combine(id)
      case .featured:
        hasher.combine("featured")
      case .ads:
        hasher.combine("ads")
      }
    }
  }
  
  enum Item: Hashable {
    case empty
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
