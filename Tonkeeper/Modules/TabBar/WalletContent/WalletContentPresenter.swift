//
//  WalletContentWalletContentPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/05/2023.
//

import UIKit
import WalletCore

final class WalletContentPresenter {
  
  // MARK: - Module
  
  weak var viewInput: WalletContentViewInput?
  weak var output: WalletContentModuleOutput?
  private var pageOutputMediator = WalletContentPageOutputMediator()
  private var pageInputs = [WalletContentPageInput]()
  
  // MARK: - Dependencies
  
  private let walletBalanceModelMapper: WalletBalanceModelMapper
  
  // MARK: - State
  
  private var pages = [WalletBalanceModel.Page]() {
    didSet {
      reloadData()
    }
  }
  
  init(walletBalanceModelMapper: WalletBalanceModelMapper) {
    self.walletBalanceModelMapper = walletBalanceModelMapper
  }
}

// MARK: - WalletContentPresenterIntput

extension WalletContentPresenter: WalletContentPresenterInput {
  func viewDidLoad() {
    pageOutputMediator.output = self
  }
}

// MARK: - WalletContentModuleInput

extension WalletContentPresenter: WalletContentModuleInput {
  func updateWith(walletPages: [WalletBalanceModel.Page]) {
    self.pages = walletPages
  }
}

// MARK: - WalletContentPageOutputMediator

extension WalletContentPresenter: WalletContentPageOutput {
  func walletContentPageInput(_ input: WalletContentPageInput, didSelectItemAt indexPath: IndexPath) {
    guard let pageIndex = pageInputs.firstIndex(where: { $0 === input }) else { return }
    let section = pages[pageIndex].sections[indexPath.section]
    switch section {
    case .token(let items):
      let item = items[indexPath.item]
      output?.didSelectItem(item: item)
    case .collectibles(let items):
      let item = items[indexPath.item]
      output?.didSelectCollectibleItem(item)
    }
  }
}

// MARK: - Private

private extension WalletContentPresenter {
  func reloadData() {
    let pages = walletBalanceModelMapper.map(pages: pages)
    pageInputs = []
    
    let contentPages = pages.compactMap { page -> PagingContent? in
      guard let contentPage = output?.getPageContent(page: page, output: pageOutputMediator) else { return nil }
      pageInputs.append(contentPage.1)
      return contentPage.0
    }
    viewInput?.updateContentPages(contentPages)
  }
}
