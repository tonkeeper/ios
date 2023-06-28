//
//  AppAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class AppAssembly {
  
  lazy var tabBarAssembly = TabBarAssembly()
  lazy var onboardingAssembly = OnboardingAssembly()
  
  func tabBarCoordinator() -> TabBarCoordinator {
    let tabBarController = UITabBarController()
    tabBarController.configureAppearance()
    let router = TabBarRouter(rootViewController: tabBarController)
    let coordinator = TabBarCoordinator(router: router, assembly: tabBarAssembly)
    return coordinator
  }
  
  func onboardingCoordinator() -> OnboardingCoordinator {
    let navigationController = UINavigationController()
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = OnboardingCoordinator(router: router,
                                            assembly: onboardingAssembly)
    return coordinator
  }
}
