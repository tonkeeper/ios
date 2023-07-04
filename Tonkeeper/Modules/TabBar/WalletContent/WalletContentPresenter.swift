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
  func viewDidLoad() {}
}

// MARK: - WalletContentModuleInput

extension WalletContentPresenter: WalletContentModuleInput {
  func updateWith(walletPages: [WalletBalanceModel.Page]) {
    self.pages = walletPages
  }
}

// MARK: - TokensListModuleInput

extension WalletContentPresenter: TokensListModuleOutput {}

// MARK: - Private

private extension WalletContentPresenter {
  func reloadData() {
    let pages = walletBalanceModelMapper.map(pages: pages)
    
    let contentPages = pages.compactMap {
      output?.getPagingContent(page: $0)
    }
  
    viewInput?.updateContentPages(contentPages)
  }
}
