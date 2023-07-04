//
//  WalletRootProtocols.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import Foundation

protocol WalletRootModuleOutput: AnyObject {
  func openQRScanner()
  func openSend(address: String?)
  func openReceive(address: String)
  func openBuy()
}

protocol WalletRootPresenterInput {
  func viewDidLoad()
  func didPullToRefresh()
}

protocol WalletRootViewInput: AnyObject {
  func didFinishLoading()
}
