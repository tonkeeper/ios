import UIKit
import TKUIKit
import TKCore
import KeeperCore

public protocol SettingsListModuleOutput: AnyObject {}

protocol SettingsListViewModel: AnyObject {
  var didUpdateTitle: ((String) -> Void)? { get set }
  var didUpdateSnapshot: ((SettingsListViewController.Snapshot) -> Void)? { get set }
  var didSelectItem: ((SettingsListViewController.Item?) -> Void)? { get set }
  var didShowPopupMenu: (([TKPopupMenuItem], Int?) -> Void)? { get set }
  
  func viewDidLoad()
  func shouldSelect() -> Bool
}

struct SettingsListState {
  let sections: [SettingsListSection]
  let selectedItem: AnyHashable?
}

protocol SettingsListConfigurator: AnyObject {
  var didUpdateState: ((SettingsListState) -> Void)? { get set }
  var didShowPopupMenu: ((_ menuItems: [TKPopupMenuItem],
                          _ selectedIndex: Int?) -> Void)? { get set }
  
  var title: String { get }
  var isSelectable: Bool { get }
  
  func getState() -> SettingsListState
}

final class SettingsListViewModelImplementation: SettingsListViewModel, SettingsListModuleOutput {
  
  // MARK: - SettingsListModuleOutput
  
  // MARK: - SettingsListViewModel
  
  var didUpdateTitle: ((String) -> Void)?
  var didUpdateSnapshot: ((SettingsListViewController.Snapshot) -> Void)?
  var didSelectItem: ((SettingsListViewController.Item?) -> Void)?
  var didShowPopupMenu: (([TKPopupMenuItem], Int?) -> Void)?
  
  func viewDidLoad() {
    configurator.didUpdateState = { [weak self] state in
      DispatchQueue.main.async {
        self?.update(state: state)
      }
    }
    configurator.didShowPopupMenu = { [weak self] items, selectedIndex in
      DispatchQueue.main.async {
        self?.didShowPopupMenu?(items, selectedIndex)
      }
    }
    didUpdateTitle?(configurator.title)
    let state = configurator.getState()
    update(state: state)
  }
  
  func shouldSelect() -> Bool {
    configurator.isSelectable
  }
  
  private let configurator: SettingsListConfigurator
  
  init(configurator: SettingsListConfigurator) {
    self.configurator = configurator
  }
  
  private func update(state: SettingsListState) {
    var snapshot = SettingsListViewController.Snapshot()
    snapshot.appendSections(state.sections)
    for section in state.sections {
      switch section {
      case .items(_, let items, _,  _):
        snapshot.appendItems(items, toSection: section)
      }
    }
    
    didUpdateSnapshot?(snapshot)
    if let selectedItem = state.selectedItem {
      didSelectItem?(selectedItem)
    }
  }
}

