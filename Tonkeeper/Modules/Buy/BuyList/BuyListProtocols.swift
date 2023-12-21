//
//  BuyListBuyListProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 09/06/2023.
//

import Foundation
import WalletCoreKeeper

protocol BuyListModuleOutput: AnyObject {
  func buyListModule(_ buyListModule: BuyListModuleInput,
                     showFiatMethodPopUp fiatMethod: FiatMethodViewModel)
  func buyListModule(_ buyListModule: BuyListModuleInput,
                     showWebView url: URL)
}

protocol BuyListModuleInput: AnyObject {}

protocol BuyListPresenterInput {
  func viewDidLoad()
  func didSelectServiceAt(indexPath: IndexPath)
}

protocol BuyListViewInput: AnyObject {
  func updateSections(_ sections: [BuyListSection])
}
