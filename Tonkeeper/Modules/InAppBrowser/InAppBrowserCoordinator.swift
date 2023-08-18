//
//  InAppBrowserCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 18.8.23..
//

import UIKit

protocol InAppBrowserCoordinatorOutput: AnyObject {}

final class InAppBrowserCoordinator: Coordinator<NavigationRouter> {
  weak var output: InAppBrowserCoordinatorOutput?
  
  private let url: URL
  
  init(router: NavigationRouter,
       url: URL) {
    self.url = url
    super.init(router: router)
  }

  override func start() {
    openMain()
  }
}

private extension InAppBrowserCoordinator {
  func openMain() {
    
  }
}
