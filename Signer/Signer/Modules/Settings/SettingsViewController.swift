import UIKit
import TKUIKit

final class SettingsViewController: GenericViewViewController<SettingsView> {
  private let viewModel: SettingsViewModel
  
  private lazy var collectionController = SettingsCollectionController(
    collectionView: customView.collectionView
  )
  
  private let footerView = SettingsListFooterView()
  
  init(viewModel: SettingsViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
}

private extension SettingsViewController {
  func setup() {
    collectionController.footerView = footerView
  }
  
  func setupBindings() {
    viewModel.titleUpdate = { [navigationItem] in
      navigationItem.title = $0
    }
    
    viewModel.itemsListUpdate = { [collectionController] items in
      collectionController.setItems(items)
    }
    
    viewModel.footerUpdate = { [footerView] in
      footerView.configure(model: $0)
    }
  }
}

