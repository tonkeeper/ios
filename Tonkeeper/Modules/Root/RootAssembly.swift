//
//  RootAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit

final class RootAssembly {
  let coreAssembly = CoreAssembly()
  lazy var walletCoreAssembly = WalletCoreAssembly(coreAssembly: coreAssembly)
  lazy var tabBarAssembly = TabBarAssembly(coreAssembly: coreAssembly,
                                           walletCoreAssembly: walletCoreAssembly)
  lazy var onboardingAssembly = OnboardingAssembly()
  lazy var importWalletAssembly = ImportWalletAssembly(passcodeAssembly: passcodeAssembly,
                                                       walletCoreAssembly: walletCoreAssembly)
  lazy var createWalletAssembly = CreateWalletAssembly(passcodeAssembly: passcodeAssembly,
                                                       walletCoreAssembly: walletCoreAssembly)
  lazy var passcodeAssembly = PasscodeAssembly(walletCoreAssembly: walletCoreAssembly)
  
  func tabBarCoordinator() -> TabBarCoordinator {
    let tabBarController = TabBarController()
    tabBarController.configureAppearance()
    let router = TabBarRouter(rootViewController: tabBarController)
    let coordinator = TabBarCoordinator(router: router, assembly: tabBarAssembly)
    return coordinator
  }
  
  func onboardingCoordinator(output: OnboardingCoordinatorOutput,
                             navigationRouter: NavigationRouter) -> OnboardingCoordinator {
    let coordinator = OnboardingCoordinator(router: navigationRouter,
                                            assembly: onboardingAssembly)
    coordinator.output = output
    return coordinator
  }
  
  func authenticationCoordinator(navigationRouter: NavigationRouter) -> PasscodeAuthCoordinator {
    let coordinator = PasscodeAuthCoordinator(router: navigationRouter,
                                              assembly: passcodeAssembly)
    return coordinator
  }
  
  func importWalletCoordinator(navigationRouter: NavigationRouter) -> ImportWalletCoordinator {
    let coordinator = ImportWalletCoordinator(router: navigationRouter, assembly: importWalletAssembly)
    return coordinator
  }
  
  func createWalletCoordinator(navigationRouter: NavigationRouter) -> CreateWalletCoordinator {
    let coordinator = CreateWalletCoordinator(router: navigationRouter, assembly: createWalletAssembly)
    return coordinator
  }
}
