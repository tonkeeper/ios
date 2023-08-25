//
//  CollectibleCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 21.8.23..
//

import UIKit
import TonSwift

protocol CollectibleCoordinatorOutput: AnyObject {
  func collectibleCoordinatorDidFinish(_ coordinator: CollectibleCoordinator)
}

final class CollectibleCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: CollectibleCoordinatorOutput?
  
  private let collectibleAddress: Address
  private let walletCoreAssembly: WalletCoreAssembly
  
  init(router: NavigationRouter,
       collectibleAddress: Address,
       walletCoreAssembly: WalletCoreAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
    self.collectibleAddress = collectibleAddress
    super.init(router: router)
  }
  
  override func start() {
    openCollectibleDetails()
  }
}

private extension CollectibleCoordinator {
  func openCollectibleDetails() {
    let collectibleDetailsController = walletCoreAssembly.collectibleDetailsController(collectibleAddress: collectibleAddress)
    let module = CollectibleDetailsAssembly.module(
      collectibleDetailsController: collectibleDetailsController,
      urlOpener: walletCoreAssembly.coreAssembly.urlOpener(),
      output: self
    )
    
    router.setPresentables([(module.view, nil)])
  }
}

// MARK: - CollectibleDetailsModuleOutput

extension CollectibleCoordinator: CollectibleDetailsModuleOutput {
  func collectibleDetailsDidFinish(_ collectibleDetails: CollectibleDetailsModuleInput) {
    output?.collectibleCoordinatorDidFinish(self)
  }
}
