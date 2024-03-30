import UIKit
import TKUIKit

final class WatchOnlyWalletAddressInputViewController: GenericViewViewController<WatchOnlyWalletAddressInputView>, KeyboardObserving {
  private let viewModel: WatchOnlyWalletAddressInputViewModel
  
  init(viewModel: WatchOnlyWalletAddressInputViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBindings()
    setupViewActions()
    viewModel.viewDidLoad()
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    registerForKeyboardEvents()
    customView.textField.becomeFirstResponder()
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration,
    let keyboardHeight = notification.keyboardSize?.height else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.keyboardHeight = keyboardHeight
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.keyboardHeight = 0
    }
  }
}

private extension WatchOnlyWalletAddressInputViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [weak customView] model in
      customView?.configure(model: model)
    }
    
    viewModel.didUpdateContinueButton = { [weak customView] configuration in
      customView?.continueButton.configuration = configuration
    }
    
    viewModel.didUpdateIsValid = { [weak customView] isValid in
      customView?.textField.isValid = isValid
    }
  }

  func setupViewActions() {
    customView.textField.didUpdateText = { [weak viewModel] text in
      viewModel?.text = text
    }
  }
}
