//
//  WalletContentWalletContentProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/05/2023.
//

import UIKit

protocol WalletContentModuleOutput: AnyObject {
  func getPagingContent(page: WalletContentPage) -> PagingContent
}

protocol WalletContentModuleInput: AnyObject {}

protocol WalletContentPresenterInput {
  func viewDidLoad()
}

protocol WalletContentViewInput: AnyObject {
  func updateContentPages(_ pages: [PagingContent])
}
