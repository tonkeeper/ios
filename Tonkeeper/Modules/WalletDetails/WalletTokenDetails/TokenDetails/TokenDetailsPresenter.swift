//
//  TokenDetailsTokenDetailsPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 13/07/2023.
//

import Foundation
import TKCore
import WalletCoreKeeper
import WalletCoreCore

final class TokenDetailsPresenter {
  
  // MARK: - Module
  
  weak var viewInput: TokenDetailsViewInput?
  weak var output: TokenDetailsModuleOutput?
  weak var chartInput: TonChartModuleInput?
  
  // MARK: - Dependecies
  
  private let walletProvider: WalletCoreCore.WalletProvider
  private let tokenDetailsController: WalletCoreKeeper.TokenDetailsController
  private let urlOpener: URLOpener
  
  // MARK: - Init
  
  init(walletProvider: WalletCoreCore.WalletProvider,
       tokenDetailsController: WalletCoreKeeper.TokenDetailsController,
       urlOpener: URLOpener) {
    self.walletProvider = walletProvider
    self.tokenDetailsController = tokenDetailsController
    self.urlOpener = urlOpener
    
    walletProvider.addObserver(self)
  }
}

// MARK: - TokenDetailsPresenterIntput

extension TokenDetailsPresenter: TokenDetailsPresenterInput {
  var hasAbout: Bool {
    tokenDetailsController.hasAbout
  }
  
  func viewDidLoad() {
    updateHeader()
    updateChart()
    refreshContent()
  }
  
  func didPullToRefresh() {
    refreshContent()
    chartInput?.reload()
  }
  
  func didTapTonButton() {
    output?.openURL(TonDetailsLinks.tonURL)
  }
  
  func didTapTwitterButton() {
    urlOpener.open(url: TonDetailsLinks.twitterURL)
  }
  
  func didTapChatButton() {
    urlOpener.open(url: TonDetailsLinks.chatURL)
  }
  
  func didTapCommunityButton() {
    urlOpener.open(url: TonDetailsLinks.communityURL)
  }
  
  func didTapWhitepaperButton() {
    output?.openURL(TonDetailsLinks.whitepaperURL)
  }
  
  func didTapTonViewerButton() {
    output?.openURL(TonDetailsLinks.tonviewerURL)
  }
  
  func didTapSourceCodeButton() {
    urlOpener.open(url: TonDetailsLinks.sourceCodeURL)
  }
}

// MARK: - TokenDetailsModuleInput

extension TokenDetailsPresenter: TokenDetailsModuleInput {}

// MARK: - TokenDetailsTonControllerOutput

extension TokenDetailsPresenter {
  func handleTonRecieve() {
    output?.didTapTonReceive()
  }
  
  func handleTonSend() {
    output?.didTapTonSend()
  }
  
  func handleTonSwap() {
    output?.didTapTopSwap()
  }
  
  func handleTonBuy() {
    output?.didTapTonBuy()
  }
}

// MARK: - TokenDetailsTokenControllerOutput

extension TokenDetailsPresenter {
  func handleTokenRecieve(tokenInfo: TokenInfo) {
    output?.didTapTokenReceive(tokenInfo: tokenInfo)
  }
  
  func handleTokenSend(tokenInfo: TokenInfo) {
    output?.didTapTokenSend(tokenInfo: tokenInfo)
  }
  
  func handleTokenSwap(tokenInfo: TokenInfo) {
    output?.didTapTokenSwap(tokenInfo: tokenInfo)
  }
}

extension TokenDetailsPresenter: WalletProviderObserver {
  func didUpdateActiveWallet() {
    updateHeader()
    refreshContent()
  }
}

// MARK: - Private

private extension TokenDetailsPresenter {
  func updateHeader() {
    guard let header = try? tokenDetailsController.getTokenHeader() else { return }

    let buttonsRowButtons: [ButtonsRowView.Model.ButtonModel] = header.buttons.map {
      let buttonRowButtonType: ButtonsRowView.Model.ButtonType
      switch $0 {
      case .buy:
        buttonRowButtonType = .buy
      case .send:
        buttonRowButtonType = .send
      case .receive:
        buttonRowButtonType = .receive
      case .swap:
        buttonRowButtonType = .swap
      }
      
      return ButtonsRowView.Model.ButtonModel(type: buttonRowButtonType) { [weak self] in
        self?.handleButtonsRowButtonAction(type: buttonRowButtonType)
      }
    }
    
    let tokenDetailsHeaderViewModel = TokenDetailsHeaderView.Model(
      amount: header.amount,
      fiatAmount: header.fiatAmount,
      fiatPrice: nil,
      image: .with(image: header.image),
      buttonRowModel: .init(buttons: buttonsRowButtons))
    viewInput?.updateTitle(title: header.name)
    viewInput?.updateHeader(model: tokenDetailsHeaderViewModel)
  }
  
  func updateChart() {
    guard tokenDetailsController.hasChart(),
    let output = output else { return }
    let module = output.tonChartModule()
    self.chartInput = module.input
    viewInput?.showChart(module.view)
  }
  
  func refreshContent() {
    Task {
      do {
        try await tokenDetailsController.reloadContent()
        Task { @MainActor in
          updateHeader()
          viewInput?.stopRefresh()
        }
      } catch {
        Task { @MainActor in
          viewInput?.stopRefresh()
        }
      }
    }
  }
  
  func handleButtonsRowButtonAction(type: ButtonsRowView.Model.ButtonType) {
    switch type {
    case .receive:
      tokenDetailsController.handleRecieve()
    case .swap:
      tokenDetailsController.handleSwap()
    case .send:
      tokenDetailsController.handleSend()
    case .buy:
      tokenDetailsController.handleBuy()
    case .sell:
      break
    }
  }
}
