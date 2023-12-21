//
//  ActivityRootActivityRootProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import Foundation
import TonSwift
import WalletCoreKeeper

protocol ActivityRootModuleOutput: AnyObject {
  func didTapReceiveButton()
  func didSelectAction(_ action: ActivityEventAction)
  func didSelectCollectible(address: Address)
}

protocol ActivityRootModuleInput: AnyObject {}

protocol ActivityRootPresenterInput {
  func viewDidLoad()
}

protocol ActivityRootViewInput: AnyObject {
  func showEmptyState()
  func showList()
  func updateTitle(_ title: String)
  func setIsConnecting(_ isConnecting: Bool)
}
