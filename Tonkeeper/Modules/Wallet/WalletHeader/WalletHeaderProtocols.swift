//
//  WalletHeaderProtocols.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import Foundation
import WalletCoreKeeper

protocol WalletHeaderModuleOutput: AnyObject {
  func didTapSendButton()
  func didTapReceiveButton()
  func didTapBuyButton()
  func openQRScanner()
  func didTapAddress()
}

protocol WalletHeaderModuleInput: AnyObject {
  func updateTitleView(with model: TitleConnectionView.Model)
  func updateWith(walletHeader: WalletBalanceModel.Header)
}

protocol WalletHeaderPresenterInput {
  func viewDidLoad()
  func didTapAddressButton()
  func didTapScanQRButton()
}

protocol WalletHeaderViewInput: AnyObject {
  func update(with model: WalletHeaderView.Model)
  func updateTitleView(with model: TitleConnectionView.Model)
  func updateButtons(with models: [WalletHeaderButtonModel])
}
