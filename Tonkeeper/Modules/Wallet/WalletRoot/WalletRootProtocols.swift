//
//  WalletRootProtocols.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import Foundation

protocol WalletRootModuleOutput: AnyObject {
  func openQRScanner()
  func openSend()
  func openReceive()
  func openBuy()
}

protocol WalletRootPresenterInput {
  func viewDidLoad()
}

protocol WalletRootViewInput: AnyObject {}
