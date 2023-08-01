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
  
  private let sendRecipientController: SendRecipientController
  private let commentLengthValidator: SendRecipientCommentLengthValidator
  private var recipient: Recipient?
  private var address: String?
  private var comment: String?
  
  // MARK: - State
  
  private var addressInputTimer: Timer?
  
  // MARK: - Init
  
  init(sendRecipientController: SendRecipientController,
       commentLengthValidator: SendRecipientCommentLengthValidator,
       address: String?) {
    self.sendRecipientController = sendRecipientController
    self.commentLengthValidator = commentLengthValidator
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
    handleAddressInput(address: address)
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
  
  func handleAddressInput(address: String) {
    addressInputTimer?.invalidate()
    guard !address.isEmpty else {
      recipient = nil
      viewInput?.updateAddressValidationState(isValid: true)
      validate()
      return
    }
    
    addressInputTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: false, block: { [weak self] timer in
      timer.invalidate()
      guard let self = self else { return }
      Task {
        let result: Bool
        do {
          self.recipient = try await self.sendRecipientController.handleInput(address)
          result = true
        } catch {
          self.recipient = nil
          result = false
        }
        await MainActor.run {
          self.validate()
          self.viewInput?.updateAddressValidationState(isValid: result)
        }
      }
    })
  }
  
  func validate() {
    let isValid = validateRecipient() && validateComment()
    viewInput?.updateContinueButtonIsAvailable(isAvailable: isValid)
  }
  
  func validateRecipient() -> Bool {
    recipient != nil
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
