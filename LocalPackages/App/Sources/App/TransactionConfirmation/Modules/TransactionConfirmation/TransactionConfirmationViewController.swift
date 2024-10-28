import UIKit
import TKUIKit

final class TransactionConfirmationViewController: GenericViewViewController<TransactionConfirmationView> {
  private let viewModel: TransactionConfirmationViewModel
  
  private let popUpViewController = TKPopUp.ViewController()
  
  init(viewModel: TransactionConfirmationViewModel) {
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

private extension TransactionConfirmationViewController {
  func setupBindings() {
    viewModel.didUpdateConfiguration = { [weak self] configuration in
      self?.popUpViewController.configuration = configuration
    }
  }
  
  func setup() {
    setupNavigationBar()
    setupModalContent()
  }
  
  private func setupNavigationBar() {
    guard let navigationController,
          !navigationController.viewControllers.isEmpty else {
      return
    }
    customView.navigationBar.leftViews = [
      TKUINavigationBar.createBackButton {
        navigationController.popViewController(animated: true)
      }
    ]
    customView.navigationBar.rightViews = [
      TKUINavigationBar.createCloseButton { [weak self] in
        self?.viewModel.didTapCloseButton()
      }
    ]
  }
  
  func setupModalContent() {
    addChild(popUpViewController)
    customView.embedContent(popUpViewController.view)
    popUpViewController.didMove(toParent: self)
  }
}
