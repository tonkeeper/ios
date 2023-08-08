//
//  WalletTokenDetailsCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 13.7.23..
//

import UIKit
import WalletCore

final class WalletTokenDetailsCoordinator: Coordinator<NavigationRouter> {
  
  private let walletCoreAssembly: WalletCoreAssembly
  private let sendAssembly: SendAssembly
  private let receiveAssembly: ReceiveAssembly
  
  let token: Token
  
  init(token: Token,
       walletCoreAssembly: WalletCoreAssembly,
       sendAssembly: SendAssembly,
       receiveAssembly: ReceiveAssembly,
       router: NavigationRouter) {
    self.token = token
    self.walletCoreAssembly = walletCoreAssembly
    self.sendAssembly = sendAssembly
    self.receiveAssembly = receiveAssembly
    super.init(router: router)
  }
  
  override func start() {
    openTokenDetails()
  }
}

private extension WalletTokenDetailsCoordinator {
  func openTokenDetails() {
    
    let tokenDetailsController: TokenDetailsController
    switch token {
    case .token(let tokenInfo):
      tokenDetailsController = walletCoreAssembly.tokenDetailsTokenController(tokenInfo: tokenInfo)
    case .ton:
      tokenDetailsController = walletCoreAssembly.tokenDetailsTonController()
    }
    
    let activityListModule = ActivityListAssembly.module(activityListController: walletCoreAssembly.activityListController(),
                                                         transactionBuilder: ActivityListTransactionBuilder(),
                                                         output: self)
    
    let module = TokenDetailsAssembly.module(output: self,
                                             activityListModule: activityListModule,
                                             tokenDetailsController: tokenDetailsController,
                                             imageLoader: NukeImageLoader())
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
  func didSelectTransaction(in section: Int, at index: Int) {} 
}
