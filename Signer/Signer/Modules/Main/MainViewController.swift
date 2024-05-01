import UIKit
import TKUIKit

final class MainViewController: GenericViewViewController<MainView> {
  private let viewModel: MainViewModel

  private lazy var collectionController = MainCollectionController(collectionView: customView.collectionView)
  
  init(viewModel: MainViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBindings()
    collectionController.headerView = customView.buttonsBarView
    viewModel.viewDidLoad()
  }
}

private extension MainViewController {
  func setupBindings() {
    viewModel.buttonsBarModelUpdate = { [customView] model in
      customView.buttonsBarView.configure(model: model)
    }
    
    viewModel.titleUpdate = { [weak self] title in
      let label = UILabel()
      label.attributedText = title
      self?.navigationItem.titleView = label
    }
    
    viewModel.itemsListUpdate = { [weak self] items in
      self?.collectionController.setItems(items)
    }
    
    collectionController.didSelectItem = { [weak self] indexPath in
      self?.viewModel.didSelectKeyItem(index: indexPath.item)
    }
  }
}
