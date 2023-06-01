//
//  SendRecipientSendRecipientPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation

final class SendRecipientPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SendRecipientViewInput?
  weak var output: SendRecipientModuleOutput?
  
  // MARK: - Dependencies
  
  private let commentLengthValidator: SendRecipientCommentLengthValidator
  
  // MARK: - Init
  
  init(commentLengthValidator: SendRecipientCommentLengthValidator) {
    self.commentLengthValidator = commentLengthValidator
  }
}

// MARK: - SendRecipientPresenterIntput

extension SendRecipientPresenter: SendRecipientPresenterInput {
  func viewDidLoad() {}
  
  func didTapCloseButton() {
    output?.sendRecipientModuleDidTapCloseButton()
  }
  
  func didTapScanQRButton() {
    output?.sendRecipientModuleOpenQRScanner()
  }
  
  func didTapContinueButton() {
    output?.sendRecipientModuleDidTapContinueButton()
  }
  
  func didChangeComment(text: String) {
    let result = commentLengthValidator.validate(text: text)
    switch result {
    case .valid:
      viewInput?.hideCommentLengthWarning()
    case .warning(let charsLeft):
      let string = "\(charsLeft) charactes left."
        .attributed(with: .body2,  alignment: .left, color: .Accent.orange)
      viewInput?.showCommentLengthWarning(text: string)
    case .notValid(let charsOver):
      let string = "Message size has been exceeded by \(charsOver) characters"
        .attributed(with: .body2,  alignment: .left, color: .Accent.red)
      viewInput?.showCommentLengthWarning(text: string)
    }
  }
}

// MARK: - SendRecipientModuleInput

extension SendRecipientPresenter: SendRecipientModuleInput {}

// MARK: - Private

private extension SendRecipientPresenter {}
