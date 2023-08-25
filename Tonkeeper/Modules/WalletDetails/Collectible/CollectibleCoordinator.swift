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
  private let sendAssembly: SendAssembly
  
  init(router: NavigationRouter,
       collectibleAddress: Address,
       walletCoreAssembly: WalletCoreAssembly,
       sendAssembly: SendAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
    self.collectibleAddress = collectibleAddress
    self.sendAssembly = sendAssembly
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
  
  func collectibleDetails(_ collectibleDetails: CollectibleDetailsModuleInput, transferCollectible collectibleAddress: Address) {
    let navigationController = UINavigationController()
    navigationController.configureDefaultAppearance()
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = sendAssembly.sendCollectibleCoordinator(router: router)
    coordinator.output = self
    
    addChild(coordinator)
    coordinator.start()
    
    self.router.present(coordinator.router.rootViewController, dismiss: { [weak self, weak coordinator] in
      guard let self = self, let coordinator = coordinator else { return }
      self.removeChild(coordinator)
    })
  }
}

// MARK: - SendCollectibleCoordinatorOutput

extension CollectibleCoordinator: SendCollectibleCoordinatorOutput {
  func sendCollectibleCoordinatorDidClose(_ coordinator: SendCollectibleCoordinator) {
    router.dismiss()
    removeChild(coordinator)
  }
}
