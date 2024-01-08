//
//  WalletRootPresenter.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import UIKit
import TKCore
import WalletCoreKeeper

struct PageContentProvider {
  let factory: (_ page: WalletContentPage, _ output: WalletContentPageOutputMediator) -> (PagingContentContainer, WalletContentPageInput)
  
  init(factory: @escaping (WalletContentPage, _ output: WalletContentPageOutputMediator) -> (PagingContentContainer, WalletContentPageInput)) {
    self.factory = factory
  }
}

final class WalletRootPresenter {
  private let balanceController: BalanceController
  private let pageContentProvider: PageContentProvider
  private let transactionsEventDaemon: TransactionsEventDaemon
  private let urlOpener: URLOpener
  private let appStateTracket = AppStateTracker()
  private let appSettings = AppSettings()

  init(balanceController: BalanceController,
       pageContentProvider: PageContentProvider,
       transactionsEventDaemon: TransactionsEventDaemon,
       urlOpener: URLOpener) {
    self.balanceController = balanceController
    self.pageContentProvider = pageContentProvider
    self.transactionsEventDaemon = transactionsEventDaemon
    self.urlOpener = urlOpener
  }
  
  deinit {
    transactionsEventDaemon.removeObserver(self)
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
    
    setupControllerBindings()
    balanceController.load()
    
    Task { didUpdateState(await transactionsEventDaemon.state)  }
    
    appStateTracket.addObserver(self)
    transactionsEventDaemon.addObserver(self)
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      self.showExperimentalBannerIfNeed()
    }
  }
}

// MARK: - Private

private extension WalletRootPresenter {
  func updateTitle() {
    headerInput?.updateTitleView(
      with: TitleConnectionView.Model(
        title: "Wallet", statusViewModel: nil
      )
    )
  }
  
  func setupControllerBindings() {
    balanceController.didUpdateBalance = { [weak self] balanceModel in
      guard let self = self else { return }
      Task { @MainActor in
        self.headerInput?.updateWith(walletHeader: balanceModel.header)
        self.contentInput?.updateWith(walletPages: balanceModel.pages)
      }
    }
    
    balanceController.didCheckDateAndTime = { [weak self] isSuccess in
      guard let self = self else { return }
      if isSuccess {
        Task { @MainActor in
          self.viewInput?.hideBannerOnTop(with: "incorrectDateAndTime")
        }
      } else {
        let incorrectDateAndTimeBannerModel = WalletHeaderBannerModel(
          identifier: "incorrectDateAndTime",
          title: "Time and date are incorrect",
          description: "In device settings, enable automatic time and date. When time isn't set automatically, it may affect fund transfers.",
          appearance: .regular)
        Task { @MainActor in
          self.viewInput?.showBannerOnTop(bannerModel: incorrectDateAndTimeBannerModel)
        }
      }
    }
  }
  
  func showExperimentalBannerIfNeed() {
    guard !appSettings.didShowExperimentalBanner else { return }

    let bannerModel = WalletHeaderBannerModel(
      identifier: "experimental",
      title: nil,
      description: "You currently using an experimental version of Tonkeeper.",
      appearance: .accentBlue,
      actionButton: WalletHeaderBannerModel.ActionButton(
        title: "Install stable version",
        action: { [urlOpener] in
          urlOpener.open(url: .tonkeeperAppstoreURL)
        }),
      closeButtonAction: { [appSettings] in
        appSettings.didShowExperimentalBanner = true
      }
    )
    
    viewInput?.showBannerOnBottom(bannerModel: bannerModel)
  }
  
  func openStableTonkeeper() {
    
  }
}

// MARK: - WalletHeaderModuleOutput

extension WalletRootPresenter: WalletHeaderModuleOutput {
  func didTapSendButton() {
    output?.openSend(recipient: nil)
  }
  
  func didTapReceiveButton() {
    guard let addresss = balanceController.address else { return }
    output?.openReceive(address: addresss.toString(bounceable: false))
  }
  
  func didTapBuyButton() {
    output?.openBuy()
  }
  
  func openQRScanner() {
    output?.openQRScanner()
  }
  
  func didTapAddress() {
    guard let address = balanceController.address else { return }
    
    ToastController.showToast(configuration: .copied)
    UIPasteboard.general.string = address.toString(bounceable: false)
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

extension WalletRootPresenter: TransactionsEventDaemonObserver {
  func didUpdateState(_ state: WalletCoreKeeper.TransactionsEventDaemonState) {
    DispatchQueue.main.async { [headerInput, balanceController] in
      let model: ConnectionStatusView.Model?
      switch state {
      case .connected:
        model = nil
        balanceController.reload()
      case .connecting:
        model = ConnectionStatusView.Model(
          title: "Updating",
          titleColor: .Text.secondary,
          isLoading: true
        )
      case .disconnected:
        model = ConnectionStatusView.Model(
          title: "Updating",
          titleColor: .Text.secondary,
          isLoading: true
        )
      case .noConnection:
        model = ConnectionStatusView.Model(
          title: "No Internet connection",
          titleColor: .Accent.orange,
          isLoading: false
        )
        balanceController.reload()
      }
      headerInput?.updateTitleView(with: TitleConnectionView.Model(title: "Wallet", statusViewModel: model))
    }
  }
  
  func didReceiveTransaction(_ transaction: WalletCoreKeeper.TransactionsEventDaemonTransaction) {
    balanceController.reload()
  }
}

extension WalletRootPresenter: AppStateTrackerObserver {
  func didUpdateState(_ state: TKCore.AppStateTracker.State) {
    switch state {
    case .active:
      balanceController.reload()
    default:
      break
    }
  }
}

private extension URL {
  static let tonkeeperAppstoreURL = URL(string: "https://apps.apple.com/us/app/tonkeeper/id1587742107")!
}

