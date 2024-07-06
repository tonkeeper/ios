import UIKit
import TKUIKit
import TKCore
import KeeperCore

public protocol SettingsListV2ModuleOutput: AnyObject {}

protocol SettingsListV2ViewModel: AnyObject {
  var didUpdateTitle: ((String) -> Void)? { get set }
  var didUpdateSnapshot: ((SettingsListV2ViewController.Snapshot) -> Void)? { get set }
  var didSelectItem: ((SettingsListV2ViewController.Item?) -> Void)? { get set }
  func viewDidLoad()
  func shouldSelect() -> Bool
}

struct SettingsListV2State {
  let sections: [SettingsListV2Section]
  let selectedItem: AnyHashable?
}

protocol SettingsListV2Configurator: AnyObject {
  var didUpdateState: ((SettingsListV2State) -> Void)? { get set }
  
  var title: String { get }
  var isSelectable: Bool { get }
  
  func getState() -> SettingsListV2State
}

final class SettingsListV2ViewModelImplementation: SettingsListV2ViewModel, SettingsListV2ModuleOutput {
  
  // MARK: - SettingsListModuleOutput
  
  // MARK: - SettingsListViewModel
  
  var didUpdateTitle: ((String) -> Void)?
  var didUpdateSnapshot: ((SettingsListV2ViewController.Snapshot) -> Void)?
  var didSelectItem: ((SettingsListV2ViewController.Item?) -> Void)?
  
  func viewDidLoad() {
    configurator.didUpdateState = { [weak self] state in
      DispatchQueue.main.async {
        self?.update(state: state)
      }
    }
    didUpdateTitle?(configurator.title)
    let state = configurator.getState()
    update(state: state)
  }
  
  func shouldSelect() -> Bool {
    configurator.isSelectable
  }
  
  private let configurator: SettingsListV2Configurator
  
  init(configurator: SettingsListV2Configurator) {
    self.configurator = configurator
  }
  
  private func update(state: SettingsListV2State) {
    var snapshot = SettingsListV2ViewController.Snapshot()
    snapshot.appendSections(state.sections)
    for section in state.sections {
      switch section {
      case .items(_, let items):
        snapshot.appendItems(items, toSection: section)
      }
    }
    
    didUpdateSnapshot?(snapshot)
    if let selectedItem = state.selectedItem {
      didSelectItem?(selectedItem)
    }
  }
}

