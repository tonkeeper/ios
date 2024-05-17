import UIKit
import TKUIKit
import SignerLocalize

protocol SettingsModuleOutput: AnyObject {}

protocol SettingsViewModel: AnyObject {
  var titleUpdate: ((String) -> Void)? { get set }
  var itemsListUpdate: ((NSDiffableDataSourceSnapshot<SettingsSection, AnyHashable>) -> Void)? { get set }
  
  func viewDidLoad()
}

final class SettingsViewModelImplementation: SettingsViewModel, SettingsModuleOutput {
  
  // MARK: - SettingsModuleOutput
  
  var didTapChangePassword: (() -> Void)?
  
  // MARK: - SettingsViewModel
  
  var titleUpdate: ((String) -> Void)?
  var itemsListUpdate: ((NSDiffableDataSourceSnapshot<SettingsSection, AnyHashable>) -> Void)?
  
  func viewDidLoad() {
    titleUpdate?(itemsProvider.title)
    
    updateList()
  }
  
  // MARK: - Dependencies
  
  private let itemsProvider: SettingsLiteItemsProvider
  
  // MARK: - Init
  
  init(itemsProvider: SettingsLiteItemsProvider) {
    self.itemsProvider = itemsProvider
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
