//
//  WalletTokenDetailsCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 13.7.23..
//

import UIKit
import WalletCoreKeeper
import TonSwift

final class WalletTokenDetailsCoordinator: Coordinator<NavigationRouter> {
  
  private let walletCoreAssembly: WalletCoreAssembly
  private let sendAssembly: SendAssembly
  private let receiveAssembly: ReceiveAssembly
  private let inAppBrowserAssembly: InAppBrowserAssembly
  
  let token: Token
  
  init(token: Token,
       walletCoreAssembly: WalletCoreAssembly,
       sendAssembly: SendAssembly,
       receiveAssembly: ReceiveAssembly,
       inAppBrowserAssembly: InAppBrowserAssembly,
       router: NavigationRouter) {
    self.token = token
    self.walletCoreAssembly = walletCoreAssembly
    self.sendAssembly = sendAssembly
    self.receiveAssembly = receiveAssembly
    self.inAppBrowserAssembly = inAppBrowserAssembly
    super.init(router: router)
  }
  
  override func start() {
    openTokenDetails()
  }
}

private extension WalletTokenDetailsCoordinator {
  func openTokenDetails() {
    
    let tokenDetailsController: TokenDetailsController
    let activityListController: ActivityListController
    switch token {
    case .token(let tokenInfo):
      tokenDetailsController = walletCoreAssembly.tokenDetailsTokenController(tokenInfo: tokenInfo)
      activityListController = walletCoreAssembly.activityListTokenEventsController(tokenInfo: tokenInfo)
    case .ton:
      tokenDetailsController = walletCoreAssembly.tokenDetailsTonController()
      activityListController = walletCoreAssembly.activityListTonEventsController()
    }
    
    let activityListModule = ActivityListAssembly.module(activityListController: activityListController,
                                                         transactionBuilder: ActivityListTransactionBuilder(
                                                          accountEventActionContentProvider: ActivityListAccountEventActionContentProvider()
                                                         ),
                                                         transactionsEventDaemon: walletCoreAssembly.transactionsEventsDaemon(),
                                                         output: self)
    
    let module = TokenDetailsAssembly.module(output: self,
                                             activityListModule: activityListModule,
                                             walletProvider: walletCoreAssembly.walletProvider,
                                             tokenDetailsController: tokenDetailsController,
                                             imageLoader: NukeImageLoader(),
                                             urlOpener: walletCoreAssembly.coreAssembly.urlOpener())
    tokenDetailsController.output = module.input
    
    module.view.setupBackButton()
    initialPresentable = module.view
  }
  
  func openSend(token: Token) {
    let navigationController = NavigationController()
    navigationController.configureDefaultAppearance()
    navigationController.isModalInPresentation = true
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = sendAssembly.coordinator(
      router: router,
      token: token,
      recipient: nil)
    coordinator.output = self
    
    addChild(coordinator)
    coordinator.start()
    self.router.present(router.rootViewController)
  }
  
  func openReceive(token: Token) {
    let navigationController = NavigationController()
    navigationController.configureTransparentAppearance()
    let router = NavigationRouter(rootViewController: navigationController)
    
    let coordinator = receiveAssembly.coordinator(router: router, flow: .token(token))
    coordinator.output = self
    
    addChild(coordinator)
    coordinator.start()
    
    self.router.present(router.rootViewController, dismiss: { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    })
  }
  
  func openBuyTon() {
    let modalCardContainerViewController = ModalCardContainerViewController()
    modalCardContainerViewController.headerSize = .big
    let router = Router(rootViewController: modalCardContainerViewController)
    let coordinator = BuyCoordinator(router: router,
                                     walletCoreAssembly: walletCoreAssembly)
    addChild(coordinator)
    coordinator.start()
    self.router.present(coordinator.router.rootViewController, dismiss: { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    })
  }
}

// MARK: - TokenDetailsModuleOutput

extension WalletTokenDetailsCoordinator: TokenDetailsModuleOutput {
  func didTapTonSend() {
    openSend(token: .ton)
  }
  
  func didTapTonReceive() {
    openReceive(token: .ton)
  }
  
  func didTapTonBuy() {
    openBuyTon()
  }
  
  func didTapTopSwap() {
    
  }
  
  func didTapTokenSend(tokenInfo: TokenInfo) {
    openSend(token: .token(tokenInfo))
  }
  
  func didTapTokenReceive(tokenInfo: TokenInfo) {
    openReceive(token: .token(tokenInfo))
  }
  
  func didTapTokenSwap(tokenInfo: TokenInfo) {
    
  }
  
  func tonChartModule() -> Module<TonChartViewController, TonChartModuleInput> {
    let module = TonChartAssembly.module(walletProvider: walletCoreAssembly.walletProvider,
                                         chartController: walletCoreAssembly.chartController(),
                                         output: self)
    return module
  }
  
  func openURL(_ url: URL) {
    let navigationController = NavigationController()
    navigationController.setNavigationBarHidden(true, animated: false)
    navigationController.modalPresentationStyle = .fullScreen
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = inAppBrowserAssembly.coordinator(router: router, url: url)
    coordinator.output = self
    addChild(coordinator)
    coordinator.start()
    self.router.present(coordinator.router.rootViewController)
  }
}

// MARK: - SendCoordinatorOutput

extension WalletTokenDetailsCoordinator: SendCoordinatorOutput {
  func sendCoordinatorDidClose(_ coordinator: SendCoordinator) {
    router.dismiss()
    removeChild(coordinator)
  }
}

// MARK: - ReceiveCoordinatorOutput

extension WalletTokenDetailsCoordinator: ReceiveCoordinatorOutput {
  func receiveCoordinatorDidClose(_ coordinator: ReceiveCoordinator) {
    router.dismiss()
    removeChild(coordinator)
  }
}

// MARK: - ActivityListModuleOutput

extension WalletTokenDetailsCoordinator: ActivityListModuleOutput {
  func didSelectAction(_ action: ActivityEventAction) {
    let module = ActivityTransactionDetailsAssembly.module(
      activityEventDetailsController: walletCoreAssembly.activityEventDetailsController(action: action),
      urlOpener: UIApplication.shared,
      output: nil
    )
    let modalCardContainerViewController = ModalCardContainerViewController(content: module.view)
    modalCardContainerViewController.headerSize = .small
    
    router.present(modalCardContainerViewController)
  }
  func activityListNoEvents(_ activityList: ActivityListModuleInput) {}
  func activityListHasEvents(_ activityList: ActivityListModuleInput) {}
  func didSetIsConnecting(_ isConnecting: Bool) {}
}

// MARK: - TonChartModuleOutput

extension WalletTokenDetailsCoordinator: TonChartModuleOutput {}

// MARK: - InAppBrowserCoordinatorOutput

extension WalletTokenDetailsCoordinator: InAppBrowserCoordinatorOutput {
  func inAppBrowserCoordinatorDidFinish(_ inAppBrowserCoordinator: InAppBrowserCoordinator) {
    self.router.dismiss()
  }
}
