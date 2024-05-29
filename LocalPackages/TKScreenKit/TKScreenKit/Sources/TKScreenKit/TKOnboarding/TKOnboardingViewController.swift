import UIKit
import TKUIKit

public final class TKOnboardingViewController: GenericViewViewController<TKOnboardingView> {
  private let viewModel: TKOnboardingViewModel
  
  init(viewModel: TKOnboardingViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBindings()
    viewModel.viewDidLoad()
  }
}

private extension TKOnboardingViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [customView] model in
      customView.configure(model: model)
    }
  }
}
