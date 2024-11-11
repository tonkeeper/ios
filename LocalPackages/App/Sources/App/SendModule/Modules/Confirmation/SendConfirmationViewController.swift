import UIKit
import TKUIKit
import TKLocalize

final class SendConfirmationViewController: GenericViewViewController<SendConfirmationView> {
  private let viewModel: SendConfirmationViewModel
  
  private let modalCardViewController = TKModalCardViewController()
  
  init(viewModel: SendConfirmationViewModel) {
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
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    viewModel.viewWillDisappear()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    viewModel.viewDidAppear()
  }
}

private extension SendConfirmationViewController {
  func setup() {
    addChild(modalCardViewController)
    customView.embedContent(modalCardViewController.view)
    modalCardViewController.didMove(toParent: self)
    
    modalCardViewController.successTitle = TKLocales.Result.success
    modalCardViewController.errorTitle = TKLocales.Result.failure
  }
  
  func setupBindings() {
    viewModel.didUpdateConfiguration = { [weak modalCardViewController] configuration in
      modalCardViewController?.configuration = configuration
    }
  }
}
