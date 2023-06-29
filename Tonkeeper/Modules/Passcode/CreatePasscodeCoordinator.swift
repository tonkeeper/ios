//
//  CreatePasscodeCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 29.6.23..
//

import UIKit

protocol CreatePasscodeCoordinatorOutput: AnyObject {
  func createPasscodeCoordinatorDidFinish(_ coordinator: CreatePasscodeCoordinator)
}

final class CreatePasscodeCoordinator: Coordinator<NavigationRouter> {

  weak var output: CreatePasscodeCoordinatorOutput?
  
  let assembly: PasscodeAssembly
  
  init(router: NavigationRouter,
       assembly: PasscodeAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
  
  override func start() {
    openCreatePasscode()
  }
}

private extension CreatePasscodeCoordinator {
  func openCreatePasscode() {
    let module = assembly.passcodeInputAssembly(output: self)
    router.push(presentable: module.view, dismiss:  { [weak self] in
      guard let self = self else { return }
      self.output?.createPasscodeCoordinatorDidFinish(self)
    })
  }
}

// MARK: - PasscodeInputModuleOutput

extension CreatePasscodeCoordinator: PasscodeInputModuleOutput {
  
}
