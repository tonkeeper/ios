//
//  WalletRootPresenter.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import UIKit
import WalletCore

struct PageContentProvider {
  let factory: (_ page: WalletContentPage, _ output: WalletContentPageOutputMediator) -> (PagingContentContainer, WalletContentPageInput)
  
  init(factory: @escaping (WalletContentPage, _ output: WalletContentPageOutputMediator) -> (PagingContentContainer, WalletContentPageInput)) {
    self.factory = factory
  }
}

final class WalletRootPresenter {
  
  private let keeperController: KeeperController
  private let walletBalanceController: WalletBalanceController
  private let pageContentProvider: PageContentProvider
  
  init(keeperController: KeeperController,
       walletBalanceController: WalletBalanceController,
       pageContentProvider: PageContentProvider) {
    self.keeperController = keeperController
    self.walletBalanceController = walletBalanceController
    self.pageContentProvider = pageContentProvider
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
  func updateTitle() {
    headerInput?.updateTitle("Wallet")
  }
  
  func getBalanceFromCache() {
    do {
      let cachedWalletState = try walletBalanceController.getWalletBalance()
      headerInput?.updateWith(walletHeader: cachedWalletState.header)
      contentInput?.updateWith(walletPages: cachedWalletState.pages)
    } catch {
      showEmptyState()
    }
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
        Task { @MainActor in
          showEmptyState()
        }
      }
      Task { @MainActor in
        viewInput?.didFinishLoading()
      }
    }
  }
  
  func showEmptyState() {
    if let emptyBalanceState = try? walletBalanceController.emptyWalletBalance() {
      headerInput?.updateWith(walletHeader: emptyBalanceState.header)
      contentInput?.updateWith(walletPages: emptyBalanceState.pages)
    }
  }
}

// MARK: - WalletHeaderModuleOutput

extension WalletRootPresenter: WalletHeaderModuleOutput {
  func didTapSendButton() {
    output?.openSend(recipient: nil)
  }
  
  func didTapReceiveButton() {
    guard let walletAddress = try? walletBalanceController.getWalletBalance().header.fullAddress else {
      return
    }
    output?.openReceive(address: walletAddress)
  }
  
  func didTapBuyButton() {
    output?.openBuy()
  }
  
  func openQRScanner() {
    output?.openQRScanner()
  }
  
  func didTapAddress() {
    guard let walletAddress = try? walletBalanceController.getWalletBalance().header.fullAddress else {
      return
    }

    ToastController.showToast(configuration: .copied)
    UIPasteboard.general.string = walletAddress
  }
}

// MARK: - WalletContentModuleOutput

extension WalletRootPresenter: WalletContentModuleOutput {
  
  func getPageContent(page: WalletContentPage, output: WalletContentPageOutputMediator) -> (PagingContent, WalletContentPageInput) {
    return pageContentProvider.factory(page, output)
  }
  
  func didSelectItem(item: WalletItemViewModel) {
    output?.didSelectItem(item)
  }
  
  func didSelectCollectibleItem(_ collectibleItem: WalletCollectibleItemViewModel) {
    output?.didSelectCollectibleItem(collectibleItem)
  }
}

private extension String {
  static let setupWalletButtonTitle = "Set up wallet"
}
