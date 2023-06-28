//
//  SetupWalletSetupWalletProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import Foundation

protocol SetupWalletModuleOutput: AnyObject {
  func didTapImportWallet()
  func didTapCreateWallet()
}

protocol SetupWalletModuleInput: AnyObject {}

protocol SetupWalletPresenterInput {
  func viewDidLoad()
}

protocol SetupWalletViewInput: AnyObject {
  func update(with modalContentConfiguration: ModalContentViewController.Configuration)
}
