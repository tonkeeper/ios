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
    var configurator = CreatePasscodeConfigurator()
    configurator.didFinish = { [weak self] passcode in
      self?.openReenterPasscode(passcode: passcode)
    }
    let module = assembly.passcodeInputAssembly(output: self, configurator: configurator)
    router.push(presentable: module.view, dismiss:  { [weak self] in
      guard let self = self else { return }
      self.output?.createPasscodeCoordinatorDidFinish(self)
    })
  }
  
  func openReenterPasscode(passcode: String) {
    var configurator = ReenterPasscodeConfigurator(createdPasscode: passcode)
    configurator.didFinish = { passcode in
      print(passcode)
    }
    configurator.didFailed = { [weak self] in
      self?.router.pop()
    }
    let module = assembly.passcodeInputAssembly(output: self, configurator: configurator)
    router.push(presentable: module.view)
  }
}

// MARK: - PasscodeInputModuleOutput

extension CreatePasscodeCoordinator: PasscodeInputModuleOutput {
  
}
