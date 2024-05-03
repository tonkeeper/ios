import UIKit
import TKUIKit

final class PasswordInputViewController: GenericViewViewController<PasswordInputView>, KeyboardObserving {
  private let viewModel: PasswordInputViewModel
  
  init(viewModel: PasswordInputViewModel) {
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
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    registerForKeyboardEvents()
    viewModel.viewWillAppear(isMovingToParent: isMovingToParent)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    viewModel.viewDidAppear()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  func keyboardWillShow(_ notification: Notification) {
    guard let keyboardSize = notification.keyboardSize,
          let duration = notification.keyboardAnimationDuration,
          let curve = notification.keyboardAnimationCurve else { return }
    customView.updateKeyboardHeight(keyboardSize.height,
                                    duration: duration,
                                    curve: curve)
  }
  
  func keyboardWillHide(_ notification: Notification) {
    guard let duration = notification.keyboardAnimationDuration,
          let curve = notification.keyboardAnimationCurve else { return }
    customView.hideKeyboard(duration: duration, curve: curve)
  }
}

private extension PasswordInputViewController {
  func setupBinding() {
    viewModel.didUpdateTitle = { [customView] model in
      customView.titleDescriptionView.configure(model: model)
    }
    viewModel.didUpdateContinueButton = { [customView] configuration in
      customView.continueButton.configuration = configuration
    }
    viewModel.didUpdateIsContinueButtonEnabled = { [customView] isEnabled in
      customView.continueButton.isEnabled = isEnabled
    }
    viewModel.didUpdateIsValidInput = { [customView] isValid in
      customView.passwordTextField.isValid = isValid
    }
    viewModel.didMakeInputActive = { [customView] in
      customView.passwordTextField.becomeFirstResponder()
    }
    
    customView.passwordTextField.didUpdateText = { [viewModel] input in
      viewModel.didUpdateInput(input)
    }
  }
}
