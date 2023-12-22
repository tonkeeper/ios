//
//  WalletRootProtocols.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import Foundation
import WalletCoreKeeper

protocol WalletRootModuleOutput: AnyObject {
  func openQRScanner()
  func openSend(recipient: Recipient?)
  func openReceive(address: String)
  func openBuy()
  func didSelectItem(_ item: WalletItemViewModel)
  func didSelectCollectibleItem(_ collectibleItem: WalletCollectibleItemViewModel)
}

protocol WalletRootPresenterInput {
  func viewDidLoad()
}

protocol WalletRootViewInput: AnyObject {
  func showBanner(bannerModel: WalletHeaderBannerModel)
  func hideBanner(with identifier: String)
}
