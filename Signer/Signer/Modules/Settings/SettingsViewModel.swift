import UIKit
import TKUIKit
import SignerLocalize

protocol SettingsModuleOutput: AnyObject {}

protocol SettingsViewModel: AnyObject {
  var titleUpdate: ((String) -> Void)? { get set }
  var itemsListUpdate: ((NSDiffableDataSourceSnapshot<SettingsSection, AnyHashable>) -> Void)? { get set }
  var showPopupMenu: (([TKPopupMenuItem], Int?, IndexPath) -> Void)? { get set }
  
  func viewDidLoad()
}

final class SettingsViewModelImplementation: SettingsViewModel, SettingsModuleOutput {
  
  // MARK: - SettingsModuleOutput
  
  var didTapChangePassword: (() -> Void)?
  
  // MARK: - SettingsViewModel
  
  var titleUpdate: ((String) -> Void)?
  var itemsListUpdate: ((NSDiffableDataSourceSnapshot<SettingsSection, AnyHashable>) -> Void)?
  var showPopupMenu: (([TKPopupMenuItem], Int?, IndexPath) -> Void)?
  
  func viewDidLoad() {
    titleUpdate?(itemsProvider.title)
    itemsProvider.didUpdate = { [weak self] in
      self?.updateList()
    }
    
    updateList()
  }
  
  // MARK: - Dependencies
  
  private var itemsProvider: SettingsLiteItemsProvider
  
  // MARK: - Init
  
  init(itemsProvider: SettingsLiteItemsProvider) {
    self.itemsProvider = itemsProvider
    self.itemsProvider.showPopupMenu = { [weak self] in
      self?.showPopupMenu?($0, $1, $2)
    }
  }
}

private extension SettingsViewModelImplementation {
  func updateList() {
    var snapshot = NSDiffableDataSourceSnapshot<SettingsSection, AnyHashable>()
    let sections = itemsProvider.getSections()
    snapshot.appendSections(sections)
    for section in sections {
      snapshot.appendItems(section.items, toSection: section)
    }
    
    itemsListUpdate?(snapshot)
  }
}
