import UIKit
import TKUIKit

final class WalletBalanceViewController: GenericViewViewController<WalletBalanceView> {
  private let viewModel: WalletBalanceViewModel

  var collectionController: WalletBalanceCollectionController?

  init(viewModel: WalletBalanceViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    collectionController = WalletBalanceCollectionController(
      collectionView: customView.collectionView,
      headerViewProvider: { [customView] in customView.headerView }
    )
    
    setupBindings()
    viewModel.viewDidLoad()
  }
}

private extension WalletBalanceViewController {
  func setupBindings() {
    viewModel.didUpdateHeader = { [weak customView] model in
      customView?.headerView.configure(model: model)
    }
    
    viewModel.didUpdateBalanceItems = { [weak collectionController] items in
      collectionController?.setBalanceItems(items)
    }
    
    collectionController?.didSelect = { [weak viewModel] section, index in
      switch section {
      case .balanceItems:
        viewModel?.didTapBalanceItem(at: index)
      }
    }
  }
}
