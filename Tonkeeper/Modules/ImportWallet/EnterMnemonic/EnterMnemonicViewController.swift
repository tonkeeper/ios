//
//  EnterMnemonicEnterMnemonicViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import UIKit

class EnterMnemonicViewController: GenericViewController<EnterMnemonicView>, KeyboardObserving {

  // MARK: - Module

  private let presenter: EnterMnemonicPresenterInput

  // MARK: - Init

  init(presenter: EnterMnemonicPresenterInput) {
    self.presenter = presenter
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    presenter.viewDidLoad()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    registerForKeyboardEvents()
  }
  
  // MARK: - Keyboard
  
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
    customView.updateKeyboardHeight(0,
                                    duration: duration,
                                    curve: curve)
  }
  
  func keyboardWillChangeFrame(_ notification: Notification) {
    guard let keyboardSize = notification.keyboardSize,
    let duration = notification.keyboardAnimationDuration,
    let curve = notification.keyboardAnimationCurve else { return }
    customView.updateKeyboardHeight(keyboardSize.height,
                                    duration: duration,
                                    curve: curve)
  }
}

// MARK: - EnterMnemonicViewInput

extension EnterMnemonicViewController: EnterMnemonicViewInput {
  func update(with model: EnterMnemonicView.Model) {
    customView.configure(model: model)
  }
  
  func showMnemonicValidationError() {
    // TBD
  }
}

extension EnterMnemonicViewController: MnemonicTextFieldDelegate {
  func didTapNextButton(textField: MnemonicTextField) {
    guard let index = customView.textFields.firstIndex(of: textField) else {
      return
    }
    let nextIndex = customView.textFields.index(after: index)
    guard nextIndex < customView.textFields.count else {
      textField.resignFirstResponder()
      return
    }
    customView.textFields[nextIndex].becomeFirstResponder()
  }
}

// MARK: - Private

private extension EnterMnemonicViewController {
  func setup() {
    customView.textFields.forEach {
      $0.addTarget(
        self,
        action: #selector(didEndEditing(textField:)),
        for: .editingDidEnd)
      $0.addTarget(
        self,
        action: #selector(didEdit(textField:)),
        for: .editingChanged)
      $0.delegate = self
    }
    
    customView.continueButton.addTarget(
      self,
      action: #selector(didTapContinueButton),
      for: .touchUpInside
    )
    
    customView.textFields.forEach { $0.text = "keen" }
  }
  
  func updateContinueButtonState() {
    let isValid = customView.textFields.map {
      guard let text = $0.text,
            !text.isEmpty,
            $0.validationState == .valid else {
        return false
      }
      return true
    }.allSatisfy { $0 }
    customView.continueButton.isEnabled = isValid
  }
  
  @objc
  func didEndEditing(textField: MnemonicTextField) {
    defer {
      updateContinueButtonState()
    }
    guard let word = textField.text,
          !word.isEmpty else {
      textField.validationState = .valid
      return
    }
    let isValid = presenter.validate(word: word)
    textField.validationState = isValid ? .valid : .invalid
  }
  
  @objc
  func didEdit(textField: MnemonicTextField) {
    defer {
      updateContinueButtonState()
    }
    let text = textField.text ?? ""
    if text.isEmpty {
      textField.validationState = .valid
    }
  }
  
  @objc
  func didTapContinueButton() {
    let mnemonic = customView.textFields.map { $0.text ?? "" }
    presenter.didEnterMnemonic(mnemonic)
  }
}
