import UIKit
import TKUIKit

final class OnboardingViewController: GenericViewViewController<OnboardingView> {
  private let viewModel: OnboardingViewModel
  
  init(viewModel: OnboardingViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBinding()
    viewModel.viewDidLoad()
  }
}

private extension OnboardingViewController {
  func setupBinding() {
    viewModel.didUpdateTitleDescription = { [customView] model in
      customView.titleDescriptionView.configure(model: model)
    }
    viewModel.didUpdateCreateButton = { [customView] model in
      customView.createButton.configure(model: model)
    }
    viewModel.didUpdateImportButton = { [customView] model in
      customView.importButton.configure(model: model)
    }
  }
}
