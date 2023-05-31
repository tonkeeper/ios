//
//  SendRecipientSendRecipientProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation

protocol SendRecipientModuleOutput: AnyObject {}

protocol SendRecipientModuleInput: AnyObject {}

protocol SendRecipientPresenterInput {
  func viewDidLoad()
}

protocol SendRecipientViewInput: AnyObject {}