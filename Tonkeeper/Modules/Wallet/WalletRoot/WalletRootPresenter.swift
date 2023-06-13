//
//  WalletRootPresenter.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import UIKit

final class WalletRootPresenter {
  
  private let pagingContentFactory: (WalletContentPage) -> PagingContent
  
  init(pagingContentFactory: @escaping (WalletContentPage) -> PagingContent) {
    self.pagingContentFactory = pagingContentFactory
  }
  
  // MARK: - Module
  
  weak var viewInput: WalletRootViewInput?
  weak var output: WalletRootModuleOutput?
  weak var headerInput: WalletHeaderModuleInput?
  weak var contentInput: WalletContentModuleInput?
}

// MARK: - WalletRootPresenterInput

extension WalletRootPresenter: WalletRootPresenterInput {
  func viewDidLoad() {
    updateTitle()
  }
}

// MARK: - WalletHeaderModuleOutput

extension WalletRootPresenter: WalletHeaderModuleOutput {
  func didTapSendButton() {
    output?.openSend()
  }
  
  func didTapReceiveButton() {
    output?.openReceive()
  }
  
  func didTapBuyButton() {
    output?.openBuy()
  }
  
  func openQRScanner() {
    output?.openQRScanner()
  }
}

// MARK: - WalletContentModuleOutput

extension WalletRootPresenter: WalletContentModuleOutput {
  func getPagingContent(page: WalletContentPage) -> PagingContent {
    return pagingContentFactory(page)
  }
  
  func updateTitle() {
    headerInput?.updateTitle("Wallet")
  }
}
