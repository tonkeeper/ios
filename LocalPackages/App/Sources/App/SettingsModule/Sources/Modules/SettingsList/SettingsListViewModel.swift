import UIKit
import TKUIKit
import TKCore
import KeeperCore

public protocol SettingsListModuleOutput: AnyObject {}

protocol SettingsListViewModel: AnyObject {
  var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }
  var didUpdateSnapshot: ((SettingsListViewController.Snapshot) -> Void)? { get set }
  var selectedItems: Set<SettingsListItem> { get }

  func viewDidLoad()
}

struct SettingsListState {
  let sections: [SettingsListSection]
}

protocol SettingsListConfigurator: AnyObject {
  var title: String { get }
  var didUpdateState: ((SettingsListState) -> Void)? { get set }
  var selectedItems: Set<SettingsListItem> { get }
  func getInitialState() -> SettingsListState
}

extension SettingsListConfigurator {
  var selectedItems: Set<SettingsListItem> { [] }
}

final class SettingsListViewModelImplementation: SettingsListViewModel, SettingsListModuleOutput {
  
  // MARK: - SettingsListModuleOutput
  
  // MARK: - SettingsListViewModel
  
  var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?
  var didUpdateSnapshot: ((SettingsListViewController.Snapshot) -> Void)?
  var selectedItems: Set<SettingsListItem> {
    configurator.selectedItems
  }
  
  func viewDidLoad() {
    didUpdateTitleView?(TKUINavigationBarTitleView.Model(title: configurator.title))
    
    configurator.didUpdateState = { [weak self] state in
      DispatchQueue.main.async {
        self?.update(with: state)
      }
    }
    
    let state = configurator.getInitialState()
    update(with: state)
  }

  
  private let configurator: SettingsListConfigurator
  
  init(configurator: SettingsListConfigurator) {
    self.configurator = configurator
  }
  
  private func update(with state: SettingsListState) {
    var snapshot = SettingsListViewController.Snapshot()
    snapshot.appendSections(state.sections)
    for section in state.sections {
      switch section {
      case .listItems(let settingsListItemsSection):
        snapshot.appendItems(settingsListItemsSection.items, toSection: section)
        if #available(iOS 15.0, *) {
          snapshot.reconfigureItems(settingsListItemsSection.items)
        } else {
          snapshot.reloadItems(settingsListItemsSection.items)
        }
      case .appInformation(let configuration):
        snapshot.appendItems([configuration], toSection: section)
        if #available(iOS 15.0, *) {
          snapshot.reconfigureItems([configuration])
        } else {
          snapshot.reloadItems([configuration])
        }
      case .button(let item):
        snapshot.appendItems([item], toSection: section)
        if #available(iOS 15.0, *) {
          snapshot.reconfigureItems([item])
        } else {
          snapshot.reloadItems([item])
        }
      }
    }
    didUpdateSnapshot?(snapshot)
  }
}

