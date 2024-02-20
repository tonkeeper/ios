import UIKit
import TKUIKit

public final class PasscodeViewController: GenericViewViewController<PasscodeView> {
  private let viewModel: PasscodeViewModel
  private let passcodeNavigationController: UINavigationController
  
  init(viewModel: PasscodeViewModel, passcodeNavigationController: UINavigationController) {
    self.viewModel = viewModel
    self.passcodeNavigationController = passcodeNavigationController
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupBindings()
    setupActions()
    viewModel.viewDidLoad()
  }
  
  public override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    
    viewModel.viewDidDisappear()
  }
}

private extension PasscodeViewController {
  func setup() {
    addChild(passcodeNavigationController)
    customView.topContainer.addSubview(passcodeNavigationController.view)
    passcodeNavigationController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      passcodeNavigationController.view.topAnchor.constraint(equalTo: customView.topContainer.topAnchor),
      passcodeNavigationController.view.leftAnchor.constraint(equalTo: customView.topContainer.leftAnchor),
      passcodeNavigationController.view.bottomAnchor.constraint(equalTo: customView.topContainer.bottomAnchor),
      passcodeNavigationController.view.rightAnchor.constraint(equalTo: customView.topContainer.rightAnchor)
    ])
    
    passcodeNavigationController.didMove(toParent: self)
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [customView] model in
      customView.configure(model: model)
    }
  }
  
  func setupActions() {
    customView.keyboardView.didTapDigit = { [viewModel] digit in
      viewModel.didTapDigitButton(digit)
    }
    
    customView.keyboardView.didTapBackspace = { [viewModel] in
      viewModel.didTapBackspaceButton()
    }
    
    customView.keyboardView.didTapBiometry = { [viewModel] in
      viewModel.didTapBiometryButton()
    }
  }
}

private extension Int {
  static let dotsCount = 4
}
