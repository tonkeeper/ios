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
  
  let token: Token
  
  init(token: Token,
       walletCoreAssembly: WalletCoreAssembly,
       sendAssembly: SendAssembly,
       router: NavigationRouter) {
    self.token = token
    self.walletCoreAssembly = walletCoreAssembly
    self.sendAssembly = sendAssembly
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
    
    let module = TokenDetailsAssembly.module(output: self,
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
      address: nil)
    coordinator.output = self
    
    addChild(coordinator)
    coordinator.start()
    self.router.present(router.rootViewController)
  }
}

// MARK: - TokenDetailsModuleOutput

extension WalletTokenDetailsCoordinator: TokenDetailsModuleOutput {
  func didTapTonSend() {
    openSend(token: .ton)
  }
  
  func didTapTonReceive() {
    
  }
  
  func didTapTonBuy() {
    
  }
  
  func didTapTopSwap() {
    
  }
  
  func didTapTokenSend(tokenInfo: TokenInfo) {
    openSend(token: .token(tokenInfo))
  }
  
  func didTapTokenReceive(tokenInfo: TokenInfo) {
    
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
