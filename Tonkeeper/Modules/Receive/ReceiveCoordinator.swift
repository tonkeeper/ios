//
//  ReceiveCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 5.6.23..
//

import UIKit

protocol ReceiveCoordinatorOutput: AnyObject {
  func receiveCoordinatorDidClose(_ coordinator: ReceiveCoordinator)
}

final class ReceiveCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: ReceiveCoordinatorOutput?
  
  private let assembly: ReceiveAssembly
  
  init(router: NavigationRouter,
       assembly: ReceiveAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
  
  override func start() {
    openRootReceive()
  }
}

private extension ReceiveCoordinator {
  func openRootReceive() {
    let module = assembly.receieveModule(output: self)
    router.setPresentables([(module.view, nil)])
  }
}

// MARK: - ReceiveModuleOutput

extension ReceiveCoordinator: ReceiveModuleOutput {
  func receieveModuleDidTapCloseButton() {
    output?.receiveCoordinatorDidClose(self)
  }
}

