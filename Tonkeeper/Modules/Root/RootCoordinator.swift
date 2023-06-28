//
//  RootCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit

final class RootCoordinator: Coordinator<NavigationRouter> {
  
  private let assembly: RootAssembly
 
  init(router: NavigationRouter,
       assembly: RootAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
  
  override func start() {
    let appSettings = assembly.coreAssembly.appSetting
    if appSettings.didShowOnboarding {
      openTabBar()
    } else {
      openOnboarding()
    }
  }
}

private extension RootCoordinator {
  func openTabBar() {
    let coordinator = assembly.tabBarCoordinator()
    coordinator.output = self
    router.setPresentables([(coordinator.router.rootViewController, nil)])
    addChild(coordinator)
    coordinator.start()
  }
  
  func openOnboarding() {
    let coordinator = assembly.onboardingCoordinator(
      output: self,
      navigationRouter: router)
    addChild(coordinator)
    coordinator.start()
  }
}

// MARK: - OnboardingCoordinatorOutput

extension RootCoordinator: OnboardingCoordinatorOutput {
  func onboardingCoordinatorDidFinish(_ coordinator: OnboardingCoordinator) {
    let appSettings = assembly.coreAssembly.appSetting
    appSettings.didShowOnboarding = true
    removeChild(coordinator)
    openTabBar()
  }
}

// MARK: - TabBarCoordinatorOutput

extension RootCoordinator: TabBarCoordinatorOutput {
  func tabBarCoordinatorOpenImportWallet(_ coordinator: TabBarCoordinator) {
    let importWalletCoordinator = assembly.importWalletCoordinator(navigationRouter: router)
    addChild(importWalletCoordinator)
    importWalletCoordinator.start()
  }
  
  func tabBarCoordinatorOpenCreateWallet(_ coordinator: TabBarCoordinator) {
    
  }
}

