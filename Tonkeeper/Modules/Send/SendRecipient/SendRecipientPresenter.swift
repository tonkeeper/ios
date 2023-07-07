//
//  SendRecipientSendRecipientPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation
import WalletCore

final class SendRecipientPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SendRecipientViewInput?
  weak var output: SendRecipientModuleOutput?
  
  // MARK: - Dependencies
  
  private let commentLengthValidator: SendRecipientCommentLengthValidator
  private let addressValidator: AddressValidator
  private var address: String?
  private var comment: String?
  
  // MARK: - Init
  
  init(commentLengthValidator: SendRecipientCommentLengthValidator,
       addressValidator: AddressValidator,
       address: String?) {
    self.commentLengthValidator = commentLengthValidator
    self.addressValidator = addressValidator
    self.address = address
  }
}

// MARK: - SendRecipientPresenterIntput

extension SendRecipientPresenter: SendRecipientPresenterInput {
  func viewDidLoad() {
    updateRecipient()
    validate()
  }
  
  func didTapCloseButton() {
    output?.sendRecipientModuleDidTapCloseButton()
  }
  
  func didTapScanQRButton() {
    output?.sendRecipientModuleOpenQRScanner()
  }
  
  func didTapContinueButton() {
    output?.sendRecipientModuleDidTapContinueButton(address: address ?? "", comment: comment)
  }
  
  func didChangeComment(text: String) {
    self.comment = text
    validate()
  }
  
  func didChangeAddress(address: String) {
    self.address = address
    validate()
  }
}

// MARK: - SendRecipientModuleInput

extension SendRecipientPresenter: SendRecipientModuleInput {
  func setAddress(_ address: String) {
    self.address = address
    updateRecipient()
    validate()
  }
}

// MARK: - Private

private extension SendRecipientPresenter {
  func updateRecipient() {
    guard let address = address else {
      return
    }
    viewInput?.updateRecipientAddress(address)
  }
  
  func validate() {
    let isValid = validateAddress() && validateComment()
    viewInput?.updateContinueButtonIsAvailable(isAvailable: isValid)
  }
  
  func validateAddress() -> Bool {
    guard let address = address,
          !address.isEmpty else {
      viewInput?.updateAddressValidationState(isValid: true)
      return false
    }
    
    let isValid = addressValidator.validateAddress(address)
    viewInput?.updateAddressValidationState(isValid: isValid)
    return isValid
  }
  
  func validateComment() -> Bool {
    let result = commentLengthValidator.validate(text: comment ?? "")
    let isValid: Bool
    switch result {
    case .valid:
      viewInput?.hideCommentLengthWarning()
      isValid = true
    case .warning(let charsLeft):
      let string = "\(charsLeft) charactes left."
        .attributed(with: .body2,  alignment: .left, color: .Accent.orange)
      viewInput?.showCommentLengthWarning(text: string)
      isValid = true
    case .notValid(let charsOver):
      let string = "Message size has been exceeded by \(charsOver) characters"
        .attributed(with: .body2,  alignment: .left, color: .Accent.red)
      viewInput?.showCommentLengthWarning(text: string)
      isValid = false
    }
    return isValid
  }
}
