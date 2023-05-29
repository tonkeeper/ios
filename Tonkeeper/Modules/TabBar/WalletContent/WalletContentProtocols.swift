//
//  WalletContentWalletContentProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/05/2023.
//

import Foundation

protocol WalletContentModuleOutput: AnyObject {}

protocol WalletContentModuleInput: AnyObject {}

protocol WalletContentPresenterInput {
  func viewDidLoad()
}

protocol WalletContentViewInput: AnyObject {}