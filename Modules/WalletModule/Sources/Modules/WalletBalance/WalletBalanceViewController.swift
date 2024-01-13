import UIKit
import TKUIKit

final class WalletBalanceViewController: GenericViewViewController<WalletBalanceView> {
  private let viewModel: WalletBalanceViewModel
  
  private lazy var collectionController = WalletBalanceCollectionController(
    collectionView: customView.collectionView,
    headerViewProvider: { [customView] in customView.headerView }
  )
  
  init(viewModel: WalletBalanceViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBindings()
    viewModel.viewDidLoad()
    collectionController.description
  }
}

private extension WalletBalanceViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [customView] model in
      customView.configure(model: model)
    }
  }
}
