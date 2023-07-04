//
//  SendRecipientSendRecipientProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation

protocol SendRecipientModuleOutput: AnyObject {
  func sendRecipientModuleDidTapCloseButton()
  func sendRecipientModuleOpenQRScanner()
  func sendRecipientModuleDidTapContinueButton()
}

protocol SendRecipientModuleInput: AnyObject {
  func setAddress(_ address: String)
}

protocol SendRecipientPresenterInput {
  func viewDidLoad()
  func didTapCloseButton()
  func didTapScanQRButton()
  func didChangeComment(text: String)
  func didTapContinueButton()
}

protocol SendRecipientViewInput: AnyObject {
  func updateRecipientAddress(_ address: String)
  func showCommentLengthWarning(text: NSAttributedString)
  func hideCommentLengthWarning()
}
