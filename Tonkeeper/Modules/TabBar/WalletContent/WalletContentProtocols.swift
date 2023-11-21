//
//  WalletContentWalletContentProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/05/2023.
//

import UIKit
import WalletCoreKeeper

protocol WalletContentPageInput: AnyObject {}
protocol WalletContentPageOutput: AnyObject {
  func walletContentPageInput(_ input: WalletContentPageInput, didSelectItemAt indexPath: IndexPath)
}

protocol WalletContentModuleOutput: AnyObject {
  func getPageContent(page: WalletContentPage, output: WalletContentPageOutputMediator) -> (PagingContent, WalletContentPageInput)
  func didSelectItem(item: WalletItemViewModel)
  func didSelectCollectibleItem(_ collectibleItem: WalletCollectibleItemViewModel)
}

protocol WalletContentModuleInput: AnyObject {
  func updateWith(walletPages: [WalletBalanceModel.Page])
}

protocol WalletContentPresenterInput {
  func viewDidLoad()
}

protocol WalletContentViewInput: AnyObject {
  func updateContentPages(_ pages: [PagingContent])
}
