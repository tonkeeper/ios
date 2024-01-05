//
//  SendRecipientSendRecipientPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation
import WalletCoreKeeper
import TonSwift

final class SendRecipientPresenter {
  
  // MARK: - Module
  
  weak var viewInput: SendRecipientViewInput?
  weak var output: SendRecipientModuleOutput?
  
  // MARK: - Dependencies
  
  private let sendRecipientController: SendRecipientController
  private let commentLengthValidator: SendRecipientCommentLengthValidator
  private let knownAccounts: KnownAccounts
  private var recipient: Recipient?
  private var comment: String?
  
  private var isRequireMemo = false {
    didSet {
      Task { @MainActor in
        if isRequireMemo {
          viewInput?.setRequireMemoState()
        } else {
          viewInput?.setNotRequireMemoState()
        }
        validate()
      }
    }
  }
  
  // MARK: - State
  
  private var addressInputTimer: Timer?
  
  // MARK: - Init
  
  init(sendRecipientController: SendRecipientController,
       commentLengthValidator: SendRecipientCommentLengthValidator,
       knownAccounts: KnownAccounts,
       recipient: Recipient?) {
    self.sendRecipientController = sendRecipientController
    self.commentLengthValidator = commentLengthValidator
    self.knownAccounts = knownAccounts
    self.recipient = recipient
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
    guard let recipient = recipient else { return }
    output?.sendRecipientModuleDidTapContinueButton(recipient: recipient, comment: comment)
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
  func setRecipient(_ recipient: Recipient) {
    self.recipient = recipient
    updateRecipient()
    validate()
  }
}

// MARK: - Private

private extension SendRecipientPresenter {
  func updateRecipient() {
    guard let recipient = recipient else {
      return
    }
    viewInput?.updateRecipientAddress(
      recipient.address.toString(),
      name: recipient.domain)
  }
  
  func handleAddressInput(address: String) {
    viewInput?.updateContinueButtonIsAvailable(isAvailable: false)
    addressInputTimer?.invalidate()
    handleKnownAccounts(addressString: address)
    guard !address.isEmpty else {
      recipient = nil
      viewInput?.updateAddressValidationState(isValid: true)
      validate()
      return
    }
    
    addressInputTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: false, block: { [weak self] timer in
      timer.invalidate()
      guard let self = self else { return }
      self.viewInput?.updateContinueButtonIsActivity(isActivity: true)
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
          self.viewInput?.updateContinueButtonIsActivity(isActivity: false)
          self.validate()
          self.viewInput?.updateAddressValidationState(isValid: result)
        }
      }
    })
  }
  
  func validate() {
    let isRecipientValid = validateRecipient()
    let isCommentValid = validateComment()
    viewInput?.updateContinueButtonIsAvailable(isAvailable: isRecipientValid && isCommentValid)
    
    let commentVisibilityLabelIsHidden = isRequireMemo || (comment ?? "").isEmpty
    viewInput?.updateCommentVisibilityLabelIsHidden(commentVisibilityLabelIsHidden)
  }
  
  func validateRecipient() -> Bool {
    recipient != nil
  }
  
  func validateComment() -> Bool {
    if isRequireMemo {
      let isValid = !(comment ?? "").isEmpty
      let string = "You must include the note from the exchange for transfer. Without it your funds will be lost."
        .attributed(with: .body2,  alignment: .left, color: .Accent.orange)
      viewInput?.showCommentLengthWarning(text: string)
      return isValid
    } else {
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
  
  func handleKnownAccounts(addressString: String) {
    Task {
      let address: Address
      do {
        address = try Address.parse(addressString)
      } catch {
        isRequireMemo = false
        return
      }
      let knownAccounts = await knownAccounts.knownAccounts
      guard let account = knownAccounts.first(where: { $0.address == address }) else {
        isRequireMemo = false
        return
      }
      if account.requireMemo {
        isRequireMemo = true
      } else {
        isRequireMemo = false
      }
    }
  }
}
