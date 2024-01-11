import UIKit
import TKUIKit

final class WalletBalanceViewController: GenericViewViewController<WalletBalanceView> {
  private let viewModel: WalletBalanceViewModel
  
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
  }
}

private extension WalletBalanceViewController {
  func setupBindings() {}
}
