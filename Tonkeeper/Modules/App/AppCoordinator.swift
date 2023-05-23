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
    openEmptyScreen()
  }
}

private extension AppCoordinator {
  func openEmptyScreen() {
    let emptyViewController = UIViewController()
    emptyViewController.view.backgroundColor = .Background.contentAttention
    router.setRoot(presentable: emptyViewController)
  }
}
