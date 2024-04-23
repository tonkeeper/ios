import UIKit
import TKUIKit
import TKCoordinator
import SnapKit

final class WalletContainerViewController: GenericViewViewController<WalletContainerView>, ScrollViewController {
  private let viewModel: WalletContainerViewModel
  
  private var walletBalanceViewController: UIViewController
  
  init(viewModel: WalletContainerViewModel, 
       walletBalanceViewController: UIViewController) {
    self.viewModel = viewModel
    self.walletBalanceViewController = walletBalanceViewController
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBindings()
    viewModel.viewDidLoad()
    
    addChild(walletBalanceViewController)
    customView.walletBalanceContainerView.addSubview(walletBalanceViewController.view)
    walletBalanceViewController.didMove(toParent: self)
    
    walletBalanceViewController.view.snp.makeConstraints { make in
      make.edges.equalTo(customView.walletBalanceContainerView)
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: true)
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    customView.layoutIfNeeded()
    walletBalanceViewController.additionalSafeAreaInsets.top = customView.topBarView.frame.height - customView.safeAreaInsets.top
  }
  
  func scrollToTop() {
    (walletBalanceViewController as? ScrollViewController)?.scrollToTop()
  }
}

private extension WalletContainerViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [customView] model in
      customView.configure(model: model)
    }
  }
}
