import UIKit
import TKUIKit

public final class TKInputRecoveryPhraseViewController: GenericViewViewController<TKInputRecoveryPhraseView>, KeyboardObserving {
  private let viewModel: TKInputRecoveryPhraseViewModel
  private let bannerViewProvider: (() -> UIView)?
  
  init(viewModel: TKInputRecoveryPhraseViewModel,
       bannerViewProvider: (() -> UIView)? = nil) {
    self.viewModel = viewModel
    self.bannerViewProvider = bannerViewProvider
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    customView.bannerViewProvider = bannerViewProvider
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
    guard let animationDuration = notification.keyboardAnimationDuration,
    let keyboardHeight = notification.keyboardSize?.height else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.keyboardHeight = keyboardHeight
      self.customView.layoutIfNeeded()
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.keyboardHeight = 0
      self.customView.layoutIfNeeded()
    }
  }
}

private extension TKInputRecoveryPhraseViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [customView] model in
      customView.configure(model: model)
    }
    
    viewModel.didUpdateContinueButton = { [weak customView] configuration in
      customView?.continueButton.configuration = configuration
    }
    
    viewModel.didUpdatePasteButton = { [weak customView] configuration in
      customView?.pasteButton.configuration = configuration
    }
    
    viewModel.didUpdatePasteButtonIsHidden = { [weak customView] isHidden in
      customView?.pasteButton.isHidden = isHidden
    }
    
    viewModel.didUpdateInputValidationState = { [customView] index, isValid in
      customView.inputTextFields[index].isValid = isValid
    }
    
    viewModel.didUpdateText = { [customView] index, text in
      customView.inputTextFields[index].text = text
    }
    
    viewModel.didSelectInput = { [customView] index in
      customView.scrollToInput(at: index, animationDuration: 0.35)
    }
    
    viewModel.didPaste = { [customView] index in
      customView.inputTextFields[index].becomeFirstResponder()
    }
    
    viewModel.didPastePhrase = { [customView] in
      customView.scrollToBottom(animationDuration: 0.35)
      customView.endEditing(true)
    }
    
    viewModel.didUpdateSuggests = { [customView] model in
      customView.configureSuggests(model: model)
    }
  }
}
