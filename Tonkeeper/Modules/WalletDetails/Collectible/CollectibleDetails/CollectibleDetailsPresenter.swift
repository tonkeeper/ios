//
//  CollectibleDetailsCollectibleDetailsPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 21/08/2023.
//

import Foundation
import WalletCore

final class CollectibleDetailsPresenter {
  
  // MARK: - Module
  
  weak var viewInput: CollectibleDetailsViewInput?
  weak var output: CollectibleDetailsModuleOutput?
  
  // MARK: - Dependencies
  
  private let collectibleDetailsController: CollectibleDetailsController
  
  init(collectibleDetailsController: CollectibleDetailsController) {
    self.collectibleDetailsController = collectibleDetailsController
  }
}

// MARK: - CollectibleDetailsPresenterIntput

extension CollectibleDetailsPresenter: CollectibleDetailsPresenterInput {
  func viewDidLoad() {
    updateView()
  }
  
  func didTapSwipeButton() {
    output?.collectibleDetailsDidFinish(self)
  }
}

// MARK: - CollectibleDetailsModuleInput

extension CollectibleDetailsPresenter: CollectibleDetailsModuleInput {}

// MARK: - Private

private extension CollectibleDetailsPresenter {
  func updateView() {
    let listItems: [ModalContentViewController.Configuration.ListItem] = [
      .init(left: "Owner", rightTop: .value("EQCc…G21L"), rightBottom: .value(nil)),
      .init(left: "Contract address", rightTop: .value("EQAK…OREO"), rightBottom: .value(nil))
    ]
    let model = CollectibleDetailsDetailsView.Model(titleViewModel: .init(title: "Details"),
                                                    buttonTitle: "View in explorer",
                                                    listViewModel: listItems)
    viewInput?.updateDetailsSection(model: model)
    
    let descriptionModel = CollectibleDetailsCollectionDescriptionView.Model(title: "About Eggs Wisdom", description: desc)
    viewInput?.updateContentSection(model: descriptionModel)
  }
}

let desc = """
Contests, gifts, auctions on our channel @EggsWisdom . We have established a gift fund with over 375 Telegram Usernames 💎, which we will give away to the winners of upcoming auctions free of charge.\n\nOur NFT Eggs project is planning to pursue more ambitious ideas, and we would like to give you a glimpse of what's to come.\n\nThe value of our NFTs Eggs will gradually increase as they become associated with Telegram Usernames, and we anticipate that they could appreciate by a factor of 5x to 100x⬆ their original value.\n\nIn the future, we will offer custom-designed NFTs Eggs as gifts with a unique theme of your choice.\n\nThank you for your continued support!🤝\n\nTelegram @EggsWisdom
"""
