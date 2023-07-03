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
  private let walletBalanceController: WalletBalanceController
  
  init(keeperController: KeeperController,
       walletBalanceController: WalletBalanceController,
       pagingContentFactory: @escaping (WalletContentPage) -> PagingContent) {
    self.keeperController = keeperController
    self.walletBalanceController = walletBalanceController
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
    getBalanceFromCache()
    reloadBalance()
  }
  
  func didPullToRefresh() {
    reloadBalance()
  }
}

// MARK: - Private

private extension WalletRootPresenter {
  func getBalanceFromCache() {
    do {
      let cachedWalletState = try walletBalanceController.getWalletBalance()
      headerInput?.updateWith(walletHeader: cachedWalletState.header)
      contentInput?.updateWith(walletPages: cachedWalletState.pages)
    } catch {}
  }
  
  func reloadBalance() {
    Task {
      do {
        let walletState = try await walletBalanceController.reloadWalletBalance()
        Task { @MainActor in
          headerInput?.updateWith(walletHeader: walletState.header)
          contentInput?.updateWith(walletPages: walletState.pages)
        }
      } catch {
        // TBD: Handle load error
      }
      Task { @MainActor in
        viewInput?.didFinishLoading()
      }
    }
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

private extension String {
  static let setupWalletButtonTitle = "Set up wallet"
}
