import UIKit
import TKUIKit

final class PasscodeViewController: GenericViewViewController<PasscodeView> {
  private let viewModel: PasscodeViewModel
  private let inputNavigationController: UINavigationController
  
  init(viewModel: PasscodeViewModel, 
       inputNavigationController: UINavigationController) {
    self.viewModel = viewModel
    self.inputNavigationController = inputNavigationController
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

private extension PasscodeViewController {
  func setup() {
    addChild(inputNavigationController)
    customView.topContainer.addSubview(inputNavigationController.view)
    inputNavigationController.didMove(toParent: self)
    
    inputNavigationController.view.snp.makeConstraints { make in
      make.edges.equalTo(customView.topContainer)
    }
  }
  
  func setupBindings() {
    viewModel.didEnableInput = { [weak self] in
      self?.customView.isUserInteractionEnabled = true
    }
    
    viewModel.didDisableInput = { [weak self] in
      self?.customView.isUserInteractionEnabled = false
    }
    
    customView.keyboardView.didTapButton = { [weak self] type in
      switch type {
      case .digit(let digit):
        self?.viewModel.didTapDigitButton(digit)
      case .backspace:
        self?.viewModel.didTapBackspaceButton()
      case .biometry:
        self?.viewModel.didTapBiometryButton()
      }
    }
  }
}
