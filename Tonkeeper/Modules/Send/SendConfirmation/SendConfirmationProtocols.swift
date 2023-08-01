//
//  SendConfirmationSendConfirmationProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 03/06/2023.
//

import Foundation

protocol SendConfirmationModuleOutput: AnyObject {
  func sendConfirmationModuleDidTapCloseButton()
  func sendRecipientModuleDidFinish()
}

protocol SendConfirmationModuleInput: AnyObject {}

protocol SendConfirmationPresenterInput {
  func viewDidLoad()
  func didTapCloseButton()
}

protocol SendConfirmationViewInput: AnyObject {
  func update(with configuration: ModalContentViewController.Configuration)
  func showFailedToLoadFeeError(errorTitle: String)
}
