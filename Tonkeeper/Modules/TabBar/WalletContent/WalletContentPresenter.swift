//
//  WalletContentWalletContentPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/05/2023.
//

import UIKit

final class WalletContentPresenter {
  
  // MARK: - Module
  
  weak var viewInput: WalletContentViewInput?
  weak var output: WalletContentModuleOutput?
}

// MARK: - WalletContentPresenterIntput

extension WalletContentPresenter: WalletContentPresenterInput {
  func viewDidLoad() {
    loadFakeSections()
  }
}

// MARK: - WalletContentModuleInput

extension WalletContentPresenter: WalletContentModuleInput {}

// MARK: - TokensListModuleInput

extension WalletContentPresenter: TokensListModuleOutput {}

// MARK: - Private

private extension WalletContentPresenter {
  func loadFakeSections() {
    
    let tokenItems: [TokenListTokenCell.Model] = [
      .init(title: "Toncoin",
            shortTitle: nil,
            price: "$ 1.84",
            priceDiff: "+ 7.32 %".attributed(with: .body2, alignment: .left, color: .Accent.green),
            amount: "14,787.32",
            fiatAmount: "$ 24,374.27"),
      .init(title: "Santa Coin",
            shortTitle: "SNT",
            price: "$ 4.87",
            priceDiff: "– 4.17 %".attributed(with: .body2, alignment: .left, color: .Accent.red),
            amount: "374.14",
            fiatAmount: "$ 1,823.17"),
      .init(title: "Ambra",
            shortTitle: "ABR",
            price: nil,
            priceDiff: nil,
            amount: "114.74",
            fiatAmount: nil),
      .init(title: "Kote Coin",
            shortTitle: "KOTE",
            price: nil,
            priceDiff: nil,
            amount: "114.74",
            fiatAmount: nil)
    ]
    
    let applicationItems: [TokenListTokenCell.Model] = [
      .init(title: "Whales Staking",
            shortTitle: nil,
            price: "Whales Team #1",
            priceDiff: nil,
            amount: "1,324.17",
            fiatAmount: "$ 2,443.37"),
      .init(title: "TON Staking",
            shortTitle: nil,
            price: "CAT #1",
            priceDiff: nil,
            amount: "74.24",
            fiatAmount: "$ 137.17")
    ]
    
    let collectibleItems: [TokensListCollectibleCell.Model] = [
      .init(title: "Cry Yui",
            subtitle: "TON DNS"),
      .init(title: "Unicorn Member #100",
            subtitle: "Unicorn F2F Club",
            isOnSale: true),
      .init(title: "Cry Yui",
            subtitle: "TON DNS"),
      .init(title: "Unicorn Member #100",
            subtitle: "Unicorn F2F Club"),
      .init(title: "Cry Yui",
            subtitle: "TON DNS"),
      .init(title: "Unicorn Member #100",
            subtitle: "Unicorn F2F Club"),
      .init(title: "Cry Yui",
            subtitle: "TON DNS",
            isOnSale: true),
      .init(title: "Unicorn Member #100",
            subtitle: "Unicorn F2F Club"),
      .init(title: "Cry Yui",
            subtitle: "TON DNS"),
      .init(title: "Unicorn Member #100",
            subtitle: "Unicorn F2F Club"),
      .init(title: "Cry Yui",
            subtitle: "TON DNS"),
      .init(title: "Unicorn Member #100",
            subtitle: "Unicorn F2F Club"),
      .init(title: "Cry Yui",
            subtitle: "TON DNS"),
      .init(title: "Unicorn Member #100",
            subtitle: "Unicorn F2F Club"),
      .init(title: "Cry Yui",
            subtitle: "TON DNS"),
      .init(title: "Unicorn Member #100",
            subtitle: "Unicorn F2F Club"),
      .init(title: "Cry Yui",
            subtitle: "TON DNS"),
      .init(title: "Unicorn Member #100",
            subtitle: "Unicorn F2F Club"),
      .init(title: "Cry Yui",
            subtitle: "TON DNS"),
    ]
    
    let tokensSection = TokensListSection(type: .token,
                                          items: tokenItems)
    
    let applicationSection = TokensListSection(type: .application,
                                               items: applicationItems)
    
    let collectiblesSection = TokensListSection(type: .collectibles, items: collectibleItems)
    
    let pages: [WalletContentPage] = [
      .init(title: "Tokens", sections: [tokensSection, applicationSection, collectiblesSection]),
      .init(title: "Applications", sections: [applicationSection]),
      .init(title: "Collectibles", sections: [collectiblesSection])
    ]
    
    let contentPages = pages.compactMap {
      output?.getPagingContent(page: $0)
    }
    
    
    viewInput?.updateContentPages(contentPages)
  }

}
