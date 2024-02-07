import UIKit
import TKUIKit

public final class SettingsListViewController: GenericViewViewController<SettingsListView> {
  private let viewModel: SettingsListViewModel
  
  var collectionController: SettingsListCollectionController?
  
  init(viewModel: SettingsListViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    collectionController = SettingsListCollectionController(
      collectionView: customView.collectionView,
      cellProvider: { [weak viewModel] in
        return viewModel?.cell(collectionView: $0, indexPath: $1, itemIdentifier: $2)
      }
    )
    
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
}

private extension SettingsListViewController {
  func setup() {
    customView.navigationBar.setItems([navigationItem], animated: false)
    
    navigationItem.setupBackButton { [weak self] in
      self?.navigationController?.popViewController(animated: true)
    }
  }
  
  func setupBindings() {
    viewModel.didUpdateTitle = { [weak self] title in
      self?.navigationItem.title = title
    }
    
    viewModel.didUpdateSettingsSections = { [weak collectionController] sections in
      collectionController?.setSettingsSections(sections)
    }
    
    viewModel.didShowAlert = { [weak self] title, description, actions in
      let alertController = UIAlertController(
        title: title,
        message: description,
        preferredStyle: .alert
      )
      alertController.overrideUserInterfaceStyle = .dark
      actions.forEach { alertController.addAction($0) }
      self?.present(alertController, animated: true)
    }
    
    viewModel.didSelectItem = { [weak customView] indexPath in
      customView?.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }
    
    collectionController?.didSelect = { [weak viewModel] section, index in
      viewModel?.selectItem(section: section, index: index)
    }
  }
}
