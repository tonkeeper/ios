//
//  AppAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class AppAssembly {
  
  lazy var tabBarAssembly = TabBarAssembly()
  
  func tabBarCoordinator() -> TabBarCoordinator {
    let tabBarController = UITabBarController()
    tabBarController.configureAppearance()
    let router = TabBarRouter(rootViewController: tabBarController)
    let coordinator = TabBarCoordinator(router: router, assembly: tabBarAssembly)
    return coordinator
  }
}
