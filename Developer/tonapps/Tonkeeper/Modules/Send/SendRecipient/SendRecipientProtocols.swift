//
//  SendRecipientSendRecipientProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation

protocol SendRecipientModuleOutput: AnyObject {
  func didTapCloseButton()
  func openQRScanner()
}

protocol SendRecipientModuleInput: AnyObject {}

protocol SendRecipientPresenterInput {
  func viewDidLoad()
  func didTapCloseButton()
  func didTapScanQRButton()
  func didChangeComment(text: String)
}

protocol SendRecipientViewInput: AnyObject {
  func showCommentLengthWarning(text: NSAttributedString)
  func hideCommentLengthWarning()
}
