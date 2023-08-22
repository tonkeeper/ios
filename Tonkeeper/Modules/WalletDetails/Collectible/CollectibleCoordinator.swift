//
//  CollectibleCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 21.8.23..
//

import UIKit

protocol CollectibleCoordinatorOutput: AnyObject {
  func collectibleCoordinatorDidFinish(_ coordinator: CollectibleCoordinator)
}

final class CollectibleCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: CollectibleCoordinatorOutput?
  
  override init(router: NavigationRouter) {
    super.init(router: router)
  }
  
  override func start() {
    openCollectibleDetails()
  }
}

private extension CollectibleCoordinator {
  func openCollectibleDetails() {
    let module = CollectibleDetailsAssembly.module(output: self)
    
    router.setPresentables([(module.view, nil)])
  }
}

// MARK: - CollectibleDetailsModuleOutput

extension CollectibleCoordinator: CollectibleDetailsModuleOutput {
  func collectibleDetailsDidFinish(_ collectibleDetails: CollectibleDetailsModuleInput) {
    output?.collectibleCoordinatorDidFinish(self)
  }
}
