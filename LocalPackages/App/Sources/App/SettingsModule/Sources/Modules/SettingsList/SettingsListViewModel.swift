import UIKit
import TKUIKit
import TKCore
import KeeperCore

public protocol SettingsListModuleOutput: AnyObject {
  var didTapEditWallet: ((Wallet) -> Void)? { get set }
}

protocol SettingsListViewModel: AnyObject {
  var didUpdateTitle: ((String) -> Void)? { get set }
  var didUpdateSettingsSections: (([SettingsListSection]) -> Void)? { get set }
  var didShowAlert: ((String, String?, [UIAlertAction]) -> Void)? { get set }
  var didSelectItem: ((IndexPath) -> Void)? { get set }
  
  func viewDidLoad()
  func selectItem(section: SettingsListSection, index: Int)
  func cell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: AnyHashable) -> TKCollectionViewCell?
}

protocol SettingsListItemsProvider: AnyObject {
  var didUpdateSections: (() -> Void)? { get set }
  
  var title: String { get }
  
  func getSections() -> [SettingsListSection]
  func selectItem(section: SettingsListSection, index: Int)
  func cell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: AnyHashable) -> TKCollectionViewCell?
  func initialSelectedIndexPath() -> IndexPath?
}

extension SettingsListItemsProvider {
  func initialSelectedIndexPath() -> IndexPath? { nil }
}

final class SettingsListViewModelImplementation: SettingsListViewModel, SettingsListModuleOutput {
  
  // MARK: - SettingsListModuleOutput
  
  var didTapEditWallet: ((Wallet) -> Void)?
  
  // MARK: - SettingsListViewModel
  var didUpdateTitle: ((String) -> Void)?
  var didUpdateSettingsSections: (([SettingsListSection]) -> Void)?
  var didShowAlert: ((String, String?, [UIAlertAction]) -> Void)?
  var didSelectItem: ((IndexPath) -> Void)?

  func viewDidLoad() {
    didUpdateTitle?(itemsProvider.title)
    
    itemsProvider.didUpdateSections = { [weak self] in
      guard let self = self else { return }
      self.didUpdateSettingsSections?(self.itemsProvider.getSections())
    }
    
    didUpdateSettingsSections?(itemsProvider.getSections())
    if let initialSelectedIndexPath = itemsProvider.initialSelectedIndexPath() {
      didSelectItem?(initialSelectedIndexPath)
    }
  }
  
  func selectItem(section: SettingsListSection, index: Int) {
    switch section.items[index] {
    case let item as SettingsCell.Model:
      item.selectionHandler?()
    default:
      itemsProvider.selectItem(section: section, index: index)
    }
  }
  
  func cell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: AnyHashable) -> TKCollectionViewCell? {
    itemsProvider.cell(collectionView: collectionView, indexPath: indexPath, itemIdentifier: itemIdentifier)
  }
  
  private let itemsProvider: SettingsListItemsProvider
  
  init(itemsProvider: SettingsListItemsProvider) {
    self.itemsProvider = itemsProvider
  }
}

