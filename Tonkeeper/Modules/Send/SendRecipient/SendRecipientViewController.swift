//
//  SendRecipientSendRecipientViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import UIKit

class SendRecipientViewController: GenericViewController<SendRecipientView>, KeyboardObserving {

  // MARK: - Module

  private let presenter: SendRecipientPresenterInput

  // MARK: - Init

  init(presenter: SendRecipientPresenterInput) {
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

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    registerForKeyboardEvents()
    if customView.addressTextField.textView.text.isEmpty {
      _ = customView.addressTextField.becomeFirstResponder()
    }
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    unregisterFromKeyboardEvents()
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

// MARK: - SendRecipientViewInput

extension SendRecipientViewController: SendRecipientViewInput {
  func updateRecipientAddress(_ address: String) {
    customView.addressTextField.text = address
  }
  
  func showCommentLengthWarning(text: NSAttributedString) {
    customView.commentLimitLabel.isHidden = false
    customView.commentLimitLabel.attributedText = text
  }
  
  func hideCommentLengthWarning() {
    customView.commentLimitLabel.isHidden = true
  }
}

// MARK: - Private

private extension SendRecipientViewController {
  func setup() {
    title = "Recipient"
    setupCloseButton { [weak self] in
      self?.presenter.didTapCloseButton()
    }
    
    customView.addressTextField.placeholder = "Address or name"
    customView.addressTextField.delegate = self
    
    customView.commentTextField.placeholder = "Comment"
    customView.commentTextField.delegate = self
    
    customView.addressTextField.scanQRButton.addTarget(
      self,
      action: #selector(didTapScanQRButton),
      for: .touchUpInside)
    
    customView.continueButton.addAction(.init(handler: { [weak self] in
      self?.presenter.didTapContinueButton()
    }), for: .touchUpInside)
  }
  
  func addressDidChange(_ textView: UITextView) {
    
  }
  
  func commentDidChange(_ textView: UITextView) {
    customView.commentVisibilityLabel.isHidden = textView.text.isEmpty
    presenter.didChangeComment(text: textView.text)
  }
}

// MARK: - UITextViewDelegate

extension SendRecipientViewController: UITextViewDelegate {
  func textViewDidChange(_ textView: UITextView) {
    if textView == customView.addressTextField.textView {
      addressDidChange(textView)
    }
    if textView == customView.commentTextField.textView {
      commentDidChange(textView)
    }
  }
  
  func textView(_ textView: UITextView,
                shouldChangeTextIn range: NSRange,
                replacementText text: String) -> Bool {
    return true
  }
}

// MARK: - Actions

private extension SendRecipientViewController {
  @objc
  func didTapScanQRButton() {
    presenter.didTapScanQRButton()
  }
}
