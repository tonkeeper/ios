//
//  CollectibleDetailsCollectibleDetailsProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 21/08/2023.
//

import Foundation
import TonSwift
import WalletCoreKeeper

protocol CollectibleDetailsModuleOutput: AnyObject {
  func collectibleDetailsDidFinish(_ collectibleDetails: CollectibleDetailsModuleInput)
  func collectibleDetails(
    _ collectibleDetails: CollectibleDetailsModuleInput,
    transferNFT nftAddress: Address
  )
}

protocol CollectibleDetailsModuleInput: AnyObject {}

protocol CollectibleDetailsPresenterInput {
  func viewDidLoad()
  func didTapSwipeButton()
  func didTapOpenInExplorerButton()
}

protocol CollectibleDetailsViewInput: AnyObject {
  func updateTitle(_ title: String?)
  func updateView(model: CollectibleDetailsView.Model)
}
