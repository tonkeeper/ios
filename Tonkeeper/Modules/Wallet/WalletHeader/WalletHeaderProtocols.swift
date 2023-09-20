//
//  WalletHeaderProtocols.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import Foundation
import WalletCore

protocol WalletHeaderModuleOutput: AnyObject {
  func didTapSendButton()
  func didTapReceiveButton()
  func didTapBuyButton()
  func openQRScanner()
  func didTapAddress()
}

protocol WalletHeaderModuleInput: AnyObject {
  func updateTitle(_ title: String)
  func updateWith(walletHeader: WalletBalanceModel.Header)
  func updateConnectionState(_ model: WalletHeaderConnectionStatusView.Model?)
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
  func updateConnectionState(_ model: WalletHeaderConnectionStatusView.Model?)
}
