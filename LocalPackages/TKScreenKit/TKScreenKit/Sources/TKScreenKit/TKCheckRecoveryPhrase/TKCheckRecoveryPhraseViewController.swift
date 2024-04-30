import UIKit
import TKUIKit

public final class TKCheckRecoveryPhraseViewController: GenericViewViewController<TKCheckRecoveryPhraseView>, KeyboardObserving {
  private let viewModel: TKCheckRecoveryPhraseViewModel
  
  init(viewModel: TKCheckRecoveryPhraseViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    registerForKeyboardEvents()
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    customView.inputTextFields.first?.becomeFirstResponder()
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let keyboardSize = notification.keyboardSize else { return }
    customView.scrollView.contentInset.bottom = keyboardSize.height - view.safeAreaInsets.bottom
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    customView.scrollView.contentInset.bottom = 0
  }
}

private extension TKCheckRecoveryPhraseViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [weak customView] model in
      customView?.configure(model: model)
    }
    
    viewModel.didUpdateInputValidationState = { [weak customView] index, isValid in
      customView?.inputTextFields[index].isValid = isValid
    }
    
    viewModel.didUpdateIsButtonEnabled = { [weak customView] isEnabled in
      customView?.continueButton.isEnabled = isEnabled
    }
    
    viewModel.didUpdateContinueButton = { [weak customView] configuration in
      customView?.continueButton.configuration = configuration
    }
  }
}
