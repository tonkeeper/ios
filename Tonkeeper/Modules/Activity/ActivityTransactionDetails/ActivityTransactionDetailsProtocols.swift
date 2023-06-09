//
//  ActivityTransactionDetailsActivityTransactionDetailsProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 09/06/2023.
//

import Foundation

protocol ActivityTransactionDetailsModuleOutput: AnyObject {
  func didTapViewInExplorer()
}

protocol ActivityTransactionDetailsModuleInput: AnyObject {}

protocol ActivityTransactionDetailsPresenterInput {
  func viewDidLoad()
}

protocol ActivityTransactionDetailsViewInput: AnyObject {
  func update(with modalContentConfiguration: ModalContentViewController.Configuration)
}
