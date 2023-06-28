//
//  WalletRootProtocols.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import Foundation

protocol WalletRootModuleOutput: AnyObject {
  func openCreateImportWallet()
  func openQRScanner()
  func openSend()
  func openReceive()
  func openBuy()
}

protocol WalletRootPresenterInput {
  func viewDidLoad()
  func didTapSetupWalletButton()
}

protocol WalletRootViewInput: AnyObject {
  func update(with model: WalletRootView.Model)
}
