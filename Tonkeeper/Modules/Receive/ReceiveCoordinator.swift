//
//  ReceiveCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 5.6.23..
//

import UIKit

protocol ReceiveCoordinatorOutput: AnyObject {
  func receiveCoordinatorDidClose(_ coordinator: ReceiveCoordinator)
}

final class ReceiveCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: ReceiveCoordinatorOutput?
  
  enum RecieveFlow {
    case token(Token)
    case any
  }
  
  private let walletCoreAssembly: WalletCoreAssembly
  private let flow: RecieveFlow
  
  init(router: NavigationRouter,
       walletCoreAssembly: WalletCoreAssembly,
       flow: RecieveFlow) {
    self.walletCoreAssembly = walletCoreAssembly
    self.flow = flow
    super.init(router: router)
  }
  
  override func start() {
    openRootReceive()
  }
}

private extension ReceiveCoordinator {
  func openRootReceive() {
    let provider: ReceiveRootPresenterProvider
    switch flow {
    case .any:
      provider = ReceiveRootPresenterAnyProvider()
    case .token(let token):
      switch token {
      case .ton:
        provider = ReceiveRootPresenterTonProvider()
      case .token(let tokenInfo):
        provider = ReceiveRootPresenterTokenProvider(tokenInfo: tokenInfo)
      }
    }
  
    let module = ReceiveRootAssembly.module(qrCodeGenerator: DefaultQRCodeGenerator(),
                                            deeplinkGenerator: walletCoreAssembly.deeplinkGenerator,
                                            receiveController: walletCoreAssembly.receiveController(),
                                            provider: provider,
                                            output: self)
    router.setPresentables([(module.view, nil)])
  }
}

// MARK: - ReceiveRootModuleOutput

extension ReceiveCoordinator: ReceiveRootModuleOutput {
  func receieveModuleDidTapCloseButton() {
    output?.receiveCoordinatorDidClose(self)
  }
}

