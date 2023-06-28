//
//  AppAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class AppAssembly {
  let rootAssembly = RootAssembly()
  
  func rootCoordinator() -> RootCoordinator {
    let navigationController = NavigationController()
    navigationController.setNavigationBarHidden(true, animated: false)
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = RootCoordinator(router: router, assembly: rootAssembly)
    return coordinator
  }
}
