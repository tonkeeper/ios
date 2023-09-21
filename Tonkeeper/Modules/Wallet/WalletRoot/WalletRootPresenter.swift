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
  private let appStateTracker: AppStateTracker
  private let reachabilityTracker: ReachabilityTracker
  
  init(keeperController: KeeperController,
       walletBalanceController: WalletBalanceController,
       pageContentProvider: PageContentProvider,
       appStateTracker: AppStateTracker,
       reachabilityTracker: ReachabilityTracker) {
    self.keeperController = keeperController
    self.walletBalanceController = walletBalanceController
    self.pageContentProvider = pageContentProvider
    self.appStateTracker = appStateTracker
    self.reachabilityTracker = reachabilityTracker
    appStateTracker.addObserver(self)
    reachabilityTracker.addObserver(self)
  }
  
  deinit {
    appStateTracker.removeObserver(self)
    reachabilityTracker.removeObserver(self)
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
    startBalanceObservation()
    startConnectionStateObservation()
    walletBalanceController.startUpdate()
  }
}

// MARK: - Private

private extension WalletRootPresenter {
  func updateTitle() {
    headerInput?.updateTitle("Wallet")
  }
  
  func startBalanceObservation() {
    Task {
      let balanceStream = walletBalanceController.balanceStream()
      for try await balanceModel in balanceStream {
        await MainActor.run {
          headerInput?.updateWith(walletHeader: balanceModel.header)
          contentInput?.updateWith(walletPages: balanceModel.pages)
        }
      }
    }
  }
  
  func startConnectionStateObservation() {
    Task {
      let connectionStateStream = walletBalanceController.connectionStateStream()
      for try await connectionState in connectionStateStream {
        await MainActor.run {
          switch connectionState {
          case .connected:
            headerInput?.updateConnectionState(nil)
          case .connecting:
            headerInput?.updateConnectionState(.init(title: "Updating", titleColor: .Text.secondary, isLoading: true))
          case .noInternet:
            headerInput?.updateConnectionState(.init(title: "No internet connection", titleColor: .Text.secondary, isLoading: false))
          case .failed:
            headerInput?.updateConnectionState(.init(title: "No connection", titleColor: .Accent.orange, isLoading: false))
          }
        }
      }
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

extension WalletRootPresenter: AppStateTrackerObserver {
  func didUpdateState(_ state: AppStateTracker.State) {
    switch state {
    case .becomeActive:
      walletBalanceController.startUpdate()
    case .enterBackground:
      walletBalanceController.stopUpdate()
    default:
      break
    }
  }
}

extension WalletRootPresenter: ReachabilityTrackerObserver {
  func didUpdateState(_ state: ReachabilityTracker.State) {
    switch state {
    case .connected:
      walletBalanceController.startUpdate()
    case .noInternetConnection:
      break
    }
  }
}

private extension String {
  static let setupWalletButtonTitle = "Set up wallet"
}
