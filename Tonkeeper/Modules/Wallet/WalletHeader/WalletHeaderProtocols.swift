//
//  WalletHeaderProtocols.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import Foundation

protocol WalletHeaderModuleOutput: AnyObject {
  func didTapSendButton()
  func didTapReceiveButton()
  func openQRScanner()
}

protocol WalletHeaderModuleInput: AnyObject {
  func updateTitle(_ title: String)
}

protocol WalletHeaderPresenterInput {
  func viewDidLoad()
  func didTapAddressButton()
  func didTapScanQRButton()
}

protocol WalletHeaderViewInput: AnyObject {
  func update(with model: WalletHeaderView.Model)
  func updateButtons(with models: [WalletHeaderButtonModel])
  func updateTitle(_ title: String?)
}
