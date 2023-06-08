//
//  ActivityCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class ActivityCoordinator: Coordinator<NavigationRouter> {
  
  private let assembly: ActivityAssembly
  
  init(router: NavigationRouter,
       assembly: ActivityAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
  
  override func start() {
    openActivityRoot()
  }
}

private extension ActivityCoordinator {
  func openActivityRoot() {
    let module = assembly.activityRootModule(output: self)
    router.setPresentables([(module.view, nil)])
  }
}

// MARK: - ActivityRootModuleOutput

extension ActivityCoordinator: ActivityRootModuleOutput {
  func didTapReceiveButton() {
    let coordinator = assembly.receieveCoordinator(output: self)
    addChild(coordinator)
    coordinator.start()
    router.present(coordinator.router.rootViewController, dismiss: { [weak self, weak coordinator] in
      self?.removeChild(coordinator!)
    })
  }
  
  func didSelectTransaction() {
  }
}

// MARK: - ReceiveCoordinatorOutput

extension ActivityCoordinator: ReceiveCoordinatorOutput {
  func receiveCoordinatorDidClose(_ coordinator: ReceiveCoordinator) {
    router.dismiss()
    removeChild(coordinator)
  }
}
