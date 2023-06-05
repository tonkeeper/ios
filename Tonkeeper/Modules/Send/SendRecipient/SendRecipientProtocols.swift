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

protocol SendRecipientModuleInput: AnyObject {}

protocol SendRecipientPresenterInput {
  func viewDidLoad()
  func didTapCloseButton()
  func didTapScanQRButton()
  func didChangeComment(text: String)
  func didTapContinueButton()
}

protocol SendRecipientViewInput: AnyObject {
  func showCommentLengthWarning(text: NSAttributedString)
  func hideCommentLengthWarning()
}
