//
//  ActivityCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit
import TonSwift

final class ActivityCoordinator: Coordinator<NavigationRouter> {
  
  private let recieveAssembly: ReceiveAssembly
  private let collectibleAssembly: CollectibleAssembly
  private let walletCoreAssembly: WalletCoreAssembly
  
  init(router: NavigationRouter,
       recieveAssembly: ReceiveAssembly,
       collectibleAssembly: CollectibleAssembly,
       walletCoreAssembly: WalletCoreAssembly) {
    self.recieveAssembly = recieveAssembly
    self.collectibleAssembly = collectibleAssembly
    self.walletCoreAssembly = walletCoreAssembly
    super.init(router: router)
  }
  
  override func start() {
    openActivityRoot()
  }
}

private extension ActivityCoordinator {
  func openActivityRoot() {
    let module = ActivityRootAssembly.module(output: self,
                                             activityController: walletCoreAssembly.activityController(),
                                             activityListController: walletCoreAssembly.activityListController())
    router.setPresentables([(module.view, nil)])
  }
}

// MARK: - ActivityRootModuleOutput

extension ActivityCoordinator: ActivityRootModuleOutput {
  func didTapReceiveButton() {
    let navigationController = NavigationController()
    navigationController.configureTransparentAppearance()
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = recieveAssembly.coordinator(router: router, flow: .any)
    coordinator.output = self
    addChild(coordinator)
    coordinator.start()
    self.router.present(coordinator.router.rootViewController, dismiss: { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    })
  }
  
  func didSelectTransaction() {
    let module = ActivityTransactionDetailsAssembly.module(output: self)
    let modalCardContainerViewController = ModalCardContainerViewController(content: module.view)
    modalCardContainerViewController.headerSize = .small
    
    router.present(modalCardContainerViewController)
  }
  
  func didSelectCollectible(address: Address) {
    let navigationController = NavigationController()
    navigationController.configureDefaultAppearance()
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = collectibleAssembly.coordinator(
      router: router,
      collectibleAddress: address
    )
    coordinator.output = self
    addChild(coordinator)
    coordinator.start()
    self.router.present(coordinator.router.rootViewController, dismiss: { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    })
  }
}

// MARK: - ReceiveCoordinatorOutput

extension ActivityCoordinator: ReceiveCoordinatorOutput {
  func receiveCoordinatorDidClose(_ coordinator: ReceiveCoordinator) {
    router.dismiss()
    removeChild(coordinator)
  }
}

// MARK: - ActivityTransactionDetailsModuleOutput

extension ActivityCoordinator: ActivityTransactionDetailsModuleOutput {
  func didTapViewInExplorer() {}
}

// MARK: - CollectibleCoordinatorOutput

extension ActivityCoordinator: CollectibleCoordinatorOutput {
  func collectibleCoordinatorDidFinish(_ coordinator: CollectibleCoordinator) {
    router.dismiss()
    removeChild(coordinator)
  }
}
