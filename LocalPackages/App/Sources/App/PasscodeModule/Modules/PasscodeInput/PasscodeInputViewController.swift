import UIKit
import TKUIKit

final class PasscodeInputViewController: GenericViewViewController<PasscodeInputView> {
  private let viewModel: PasscodeInputViewModel
  
  init(viewModel: PasscodeInputViewModel) {
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
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    
    viewModel.viewDidDisappear()
  }
  
  override func didMove(toParent parent: UIViewController?) {}
}

private extension PasscodeInputViewController {
  func setupBindings() {
    viewModel.didUpdateTitle = { [weak customView] title in
      customView?.title = title
    }
    
    viewModel.didUpdateState = { [weak customView] state, completion in
      customView?.setState(state, completion: { completion?() })
    }
  }
}

private extension Int {
  static let dotsCount = 4
}
