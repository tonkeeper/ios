import UIKit
import TKUIKit
import TKCore

final class StakingConfirmationViewController: GenericViewViewController<StakingConfirmationView> {

  private let viewModel: StakingConfirmationViewModel
  private let modalCardViewController = TKModalCardViewController()
  
  init(viewModel: StakingConfirmationViewModel) {
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

// MARK: - Private methods
 
private extension StakingConfirmationViewController {
  func setup() {
    navigationItem.setupBackButton { [weak self] in
      self?.navigationController?.popViewController(animated: true)
    }
    
    addChild(modalCardViewController)
    customView.embedContent(modalCardViewController.view)
    modalCardViewController.didMove(toParent: self)
  }
  
  func setupBindings() {
    viewModel.didUpdateConfiguration = { [weak modalCardViewController] configuration in
      modalCardViewController?.configuration = configuration
    }
    
    viewModel.didUpdateSliderActionModel = { [weak customView] model in
      customView?.sliderActionView.configure(model: model)
    }
  }
}
