//
//  WalletRootProtocols.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import Foundation

protocol WalletRootModuleOutput: AnyObject {
  func openQRScanner()
}

protocol WalletRootPresenterInput {
  func didTapScanQRButton()
}

protocol WalletRootViewInput: AnyObject {}
