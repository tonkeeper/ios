//
//  AppCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class AppCoordinator: Coordinator<WindowRouter> {
  
  private let appAssembly: AppAssembly
 
  init(router: WindowRouter,
       appAssembly: AppAssembly) {
    self.appAssembly = appAssembly
    super.init(router: router)
  }
  
  override func start() {
//    openTabBar()
    openOnboarding()
  }
}

private extension AppCoordinator {
  func openTabBar() {
    let coordinator = appAssembly.tabBarCoordinator()
    router.setRoot(presentable: coordinator.router.rootViewController)
    addChild(coordinator)
    coordinator.start()
  }
  
  func openOnboarding() {
    let coordinator = appAssembly.onboardingCoordinator()
    router.setRoot(presentable: coordinator.router.rootViewController)
    addChild(coordinator)
    coordinator.start()
  }
}
