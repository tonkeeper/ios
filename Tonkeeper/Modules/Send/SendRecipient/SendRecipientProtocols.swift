//
//  SendRecipientSendRecipientProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation
import WalletCoreKeeper

protocol SendRecipientModuleOutput: AnyObject {
  func sendRecipientModuleDidTapCloseButton()
  func sendRecipientModuleOpenQRScanner()
  func sendRecipientModuleDidTapContinueButton(recipient: Recipient, comment: String?)
}

protocol SendRecipientModuleInput: AnyObject {
  func setRecipient(_ recipient: Recipient)
}

protocol SendRecipientPresenterInput {
  func viewDidLoad()
  func didTapCloseButton()
  func didTapScanQRButton()
  func didChangeComment(text: String)
  func didChangeAddress(address: String)
  func didTapContinueButton()
}

protocol SendRecipientViewInput: AnyObject {
  func updateRecipientAddress(_ address: String, name: String?)
  func showCommentLengthWarning(text: NSAttributedString)
  func hideCommentLengthWarning()
  func updateAddressValidationState(isValid: Bool)
  func updateContinueButtonIsAvailable(isAvailable: Bool)
  func updateContinueButtonIsActivity(isActivity: Bool)
}
