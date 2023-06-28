//
//  WalletRootPresenter.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import UIKit
import WalletCore

final class WalletRootPresenter {
  
  private let pagingContentFactory: (WalletContentPage) -> PagingContent
  private let keeperController: KeeperController
  
  init(keeperController: KeeperController,
       pagingContentFactory: @escaping (WalletContentPage) -> PagingContent) {
    self.keeperController = keeperController
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
    updateRootView()
    updateTitle()
  }
  
  func didTapSetupWalletButton() {
    output?.openCreateImportWallet()
  }
  
  func handleWalletRequiredAction(_ action: () -> Void) {
    if keeperController.hasWallets {
      action()
    } else {
      output?.openCreateImportWallet()
    }
  }
}

// MARK: - WalletHeaderModuleOutput

extension WalletRootPresenter: WalletHeaderModuleOutput {
  func didTapSendButton() {
    handleWalletRequiredAction { [weak self] in
      self?.output?.openSend()
    }
  }
  
  func didTapReceiveButton() {
    handleWalletRequiredAction { [weak self] in
      self?.output?.openReceive()
    }
  }
  
  func didTapBuyButton() {
    handleWalletRequiredAction { [weak self] in
      self?.output?.openBuy()
    }
  }
  
  func openQRScanner() {
    handleWalletRequiredAction { [weak self] in
      self?.output?.openQRScanner()
    }
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
  
  func updateRootView() {
    let model = WalletRootView.Model(setupWalletButtonTitle: .setupWalletButtonTitle,
                                     isSetupWalletButtonHidden: keeperController.hasWallets)
    viewInput?.update(with: model)
  }
}

private extension String {
  static let setupWalletButtonTitle = "Set up wallet"
}
