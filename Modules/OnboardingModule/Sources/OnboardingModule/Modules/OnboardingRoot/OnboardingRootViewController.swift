import UIKit
import TKUIKit

final class OnboardingRootViewController: GenericViewViewController<OnboardingRootView> {
  private let viewModel: OnboardingRootViewModel
  
  init(viewModel: OnboardingRootViewModel) {
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

private extension OnboardingRootViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [customView] model in
      customView.configure(model: model)
    }
  }
}
