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
  
  enum RecieveFlow {
    case token(Token)
    case any
  }
  
  private let assembly: ReceiveAssembly
  private let flow: RecieveFlow
  private let address: String
  
  init(router: NavigationRouter,
       assembly: ReceiveAssembly,
       flow: RecieveFlow,
       address: String) {
    self.assembly = assembly
    self.flow = flow
    self.address = address
    super.init(router: router)
  }
  
  override func start() {
    openRootReceive()
  }
}

private extension ReceiveCoordinator {
  func openRootReceive() {
    let module = assembly.receieveModule(output: self, address: address)
    router.setPresentables([(module.view, nil)])
  }
}

// MARK: - ReceiveModuleOutput

extension ReceiveCoordinator: ReceiveModuleOutput {
  func receieveModuleDidTapCloseButton() {
    output?.receiveCoordinatorDidClose(self)
  }
}

