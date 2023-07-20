//
//  ActivityCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class ActivityCoordinator: Coordinator<NavigationRouter> {
  
  private let recieveAssembly: ReceiveAssembly
  
  init(router: NavigationRouter,
       recieveAssembly: ReceiveAssembly) {
    self.recieveAssembly = recieveAssembly
    super.init(router: router)
  }
  
  override func start() {
    openActivityRoot()
  }
}

private extension ActivityCoordinator {
  func openActivityRoot() {
    let module = ActivityRootAssembly.module(output: self)
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
    addChild(coordinator)
    coordinator.start()
    router.present(coordinator.router.rootViewController, dismiss: { [weak self, weak coordinator] in
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
