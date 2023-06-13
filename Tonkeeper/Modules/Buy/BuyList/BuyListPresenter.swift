//
//  BuyListBuyListPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 09/06/2023.
//

import Foundation

final class BuyListPresenter {
  
  // MARK: - Module
  
  weak var viewInput: BuyListViewInput?
  weak var output: BuyListModuleOutput?
  
  // MARK: - Dependencies
  
  private let buyListServiceBuilder: BuyListServiceBuilder
  
  init(buyListServiceBuilder: BuyListServiceBuilder) {
    self.buyListServiceBuilder = buyListServiceBuilder
  }
}

// MARK: - BuyListPresenterIntput

extension BuyListPresenter: BuyListPresenterInput {
  func viewDidLoad() {
    loadFakeServices()
  }
  
  func didSelectServiceAt(indexPath: IndexPath) {
      
  }
}

// MARK: - BuyListModuleInput

extension BuyListPresenter: BuyListModuleInput {}

// MARK: - Private

private extension BuyListPresenter {
  func loadFakeServices() {
    let buySectionItems: [BuyListServiceCell.Model] = [
      buyListServiceBuilder.buildServiceModel(
        logo: .Images.Mock.mercuryoLogo,
        title: "Neocrypto",
        description: "Instantly buy with a credit card",
        token: nil),
      buyListServiceBuilder.buildServiceModel(
        logo: .Images.Mock.mercuryoLogo,
        title: "Mercuryo",
        description: "Instantly buy with a credit card",
        token: nil),
      buyListServiceBuilder.buildServiceModel(
        logo: .Images.Mock.mercuryoLogo,
        title: "Wallet",
        description: "Instantly buy with a credit card",
        token: "Telegram bot"),
      buyListServiceBuilder.buildServiceModel(
        logo: .Images.Mock.mercuryoLogo,
        title: "Wallet",
        description: "Instantly buy with a credit card",
        token: "Telegram bot"),
      buyListServiceBuilder.buildServiceModel(
        logo: .Images.Mock.mercuryoLogo,
        title: "Wallet",
        description: "Instantly buy with a credit card",
        token: "Telegram bot"),
      buyListServiceBuilder.buildServiceModel(
        logo: .Images.Mock.mercuryoLogo,
        title: "Wallet",
        description: "Instantly buy with a credit card",
        token: "Telegram bot"),
      buyListServiceBuilder.buildServiceModel(
        logo: .Images.Mock.mercuryoLogo,
        title: "Wallet",
        description: "Instantly buy with a credit card",
        token: "Telegram bot"),
      buyListServiceBuilder.buildServiceModel(
        logo: .Images.Mock.mercuryoLogo,
        title: "Wallet",
        description: "Instantly buy with a credit card",
        token: "Telegram bot"),
      buyListServiceBuilder.buildServiceModel(
        logo: .Images.Mock.mercuryoLogo,
        title: "Wallet",
        description: "Instantly buy with a credit card",
        token: "Telegram bot"),
      buyListServiceBuilder.buildServiceModel(
        logo: .Images.Mock.mercuryoLogo,
        title: "Wallet",
        description: "Instantly buy with a credit card",
        token: "Telegram bot"),
      buyListServiceBuilder.buildServiceModel(
        logo: .Images.Mock.mercuryoLogo,
        title: "Wallet",
        description: "Instantly buy with a credit card",
        token: "Telegram bot"),
      buyListServiceBuilder.buildServiceModel(
        logo: .Images.Mock.mercuryoLogo,
        title: "Wallet",
        description: "Instantly buy with a credit card",
        token: "Telegram bot"),
      buyListServiceBuilder.buildServiceModel(
        logo: .Images.Mock.mercuryoLogo,
        title: "Wallet",
        description: "Instantly buy with a credit card",
        token: "Telegram bot"),
    ]
    
    let sellSectionItems: [BuyListServiceCell.Model] = [
      buyListServiceBuilder.buildServiceModel(
        logo: .Images.Mock.mercuryoLogo,
        title: "Sell with Mercuryo",
        description: "Sale with withdrawal to a credit card",
        token: nil)
    ]
    
    let sections: [BuyListSection] = [
      .init(type: .services, items: buySectionItems),
      .init(type: .services, items: sellSectionItems)
    ]
    
    viewInput?.updateSections(sections)
  }
}
