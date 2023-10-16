//
//  InAppBrowserCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 18.8.23..
//

import UIKit

protocol InAppBrowserCoordinatorOutput: AnyObject {
  func inAppBrowserCoordinatorDidFinish(_ inAppBrowserCoordinator: InAppBrowserCoordinator)
}

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
    let module = InAppBrowserMainAssembly.module(output: self, url: url)
    router.setPresentables([(module.view, nil)])
  }
}

// MARK: - InAppBrowserCoordinator

extension InAppBrowserCoordinator: InAppBrowserMainModuleOutput {
  func inAppBrowserMainDidFinish(_ inAppBrowserMain: InAppBrowserMainModuleInput) {
    output?.inAppBrowserCoordinatorDidFinish(self)
  }
}
