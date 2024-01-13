import UIKit
import TKUIKit

final class WalletContainerViewController: GenericViewViewController<WalletContainerView> {
  private let viewModel: WalletContainerViewModel
  
  private var walletBalanceViewController: UIViewController?
  
  init(viewModel: WalletContainerViewModel) {
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
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: true)
  }
}

private extension WalletContainerViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [customView] model in
      customView.configure(model: model)
    }
    
    viewModel.didUpdateWalletBalanceViewController = { [weak self] viewController, animated in
      self?.setWalletBalanceViewController(viewController, animated: animated)
    }
  }
  
  func setWalletBalanceViewController(_ viewController: UIViewController,
                                      animated: Bool) {
    let previousView = walletBalanceViewController?.view
    let previousViewController = walletBalanceViewController
    
    addChild(viewController)
    customView.walletBalanceContainerView.addSubview(viewController.view)
    viewController.view.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      viewController.view.topAnchor.constraint(equalTo: customView.walletBalanceContainerView.topAnchor),
      viewController.view.leftAnchor.constraint(equalTo: customView.walletBalanceContainerView.leftAnchor),
      viewController.view.bottomAnchor.constraint(equalTo: customView.walletBalanceContainerView.bottomAnchor),
      viewController.view.rightAnchor.constraint(equalTo: customView.walletBalanceContainerView.rightAnchor)
    ])
    
    previousViewController?.willMove(toParent: nil)
    previousView?.removeFromSuperview()
    
    UIView.transition(
      with: customView.walletBalanceContainerView,
      duration: 0.5,
      options: .transitionCrossDissolve,
      animations: nil,
      completion: { _ in
        previousViewController?.didMove(toParent: nil)
        viewController.didMove(toParent: self)
      })
    
    self.walletBalanceViewController = viewController
  }
}
