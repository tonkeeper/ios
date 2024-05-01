import UIKit
import TKUIKit
import TKScreenKit

final class InputRecoveryPhraseViewController: UIViewController, KeyboardObserving {
  private let viewModel: InputRecoveryPhraseViewModel
  
  private let recoveryPhraseViewController = TKInputRecoveryPhraseViewController()
  
  init(viewModel: InputRecoveryPhraseViewModel) {
    self.viewModel = viewModel
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
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    registerForKeyboardEvents()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    recoveryPhraseViewController.activateField(atIndex: 0)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  func keyboardWillShow(_ notification: Notification) {
    guard let keyboardSize = notification.keyboardSize else { return }
    recoveryPhraseViewController.scrollViewContentInset.bottom = keyboardSize.height - view.safeAreaInsets.bottom
  }
  
  func keyboardWillHide(_ notification: Notification) {
    recoveryPhraseViewController.scrollViewContentInset.bottom = 0
  }
}

private extension InputRecoveryPhraseViewController {
  func setup() {
    addChild(recoveryPhraseViewController)
    view.addSubview(recoveryPhraseViewController.view)
    recoveryPhraseViewController.didMove(toParent: self)
    
    recoveryPhraseViewController.didUpdateText = { [weak self] input, index in
      self?.viewModel.didInputWord(input, atIndex: index)
    }
    
    recoveryPhraseViewController.didBeginEditing = { [weak self] index in
      self?.recoveryPhraseViewController.scrollToInput(at: index, animationDuration: 0.35)
    }
    
    recoveryPhraseViewController.didEndEditing = { [weak self] index in
      self?.viewModel.didDeactivateField(atIndex: index)
    }
    
    recoveryPhraseViewController.shouldPaste = { [weak self] pasteString, index in
      (self?.viewModel.shouldPaste(pasteString: pasteString, atIndex: index) ?? true)
    }
    
    setupConstraints()
  }
  
  func setupConstraints() {
    recoveryPhraseViewController.view.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      recoveryPhraseViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
      recoveryPhraseViewController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
      recoveryPhraseViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      recoveryPhraseViewController.view.rightAnchor.constraint(equalTo: view.rightAnchor)
    ])
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [recoveryPhraseViewController] model in
      recoveryPhraseViewController.configure(with: model)
    }
    
    viewModel.didUpdateContinueButton = { [recoveryPhraseViewController] model in
      recoveryPhraseViewController.setContinueButtonModel(model)
    }
    
    viewModel.didUpdateWordValidationState = { [recoveryPhraseViewController] index, isValid in
      recoveryPhraseViewController.setValidState(isValid, at: index)
    }
    
    viewModel.didUpdateWord = { [recoveryPhraseViewController] word, index in
      recoveryPhraseViewController.setWord(word, atIndex: index)
      recoveryPhraseViewController.scrollToInput(at: index, animationDuration: 0.35)
    }
    
    viewModel.didDeselectInput = { [recoveryPhraseViewController] in
      recoveryPhraseViewController.view.endEditing(true)
    }
    
    viewModel.didSelectInput = { [recoveryPhraseViewController] index in
      recoveryPhraseViewController.activateField(atIndex: index)
    }
  }
}
