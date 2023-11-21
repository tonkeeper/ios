//
//  CreatePasscodeCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 29.6.23..
//

import UIKit
import WalletCoreKeeper
import WalletCoreCore

protocol CreatePasscodeCoordinatorOutput: AnyObject {
  func createPasscodeCoordinatorDidCreatePasscode(_ coordinator: CreatePasscodeCoordinator,
                                                  passcode: Passcode)
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
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        self?.openReenterPasscode(enteredPasscode: passcode)
      }
    }
    let module = assembly.passcodeInputAssembly(output: self, configurator: configurator)
    
    initialPresentable = module.view
  }
  
  func openReenterPasscode(enteredPasscode: Passcode) {
    var configurator = ReenterPasscodeConfigurator(createdPasscode: enteredPasscode)
    configurator.didFinish = { [weak self] passcode in
      guard let self = self else { return }
      self.output?.createPasscodeCoordinatorDidCreatePasscode(self, passcode: passcode)
    }
    configurator.didFailed = { [weak self] in
      self?.router.pop()
    }
    let module = assembly.passcodeInputAssembly(output: self, configurator: configurator)
    module.view.setupBackButton()
    router.push(presentable: module.view)
  }
}

// MARK: - PasscodeInputModuleOutput

extension CreatePasscodeCoordinator: PasscodeInputModuleOutput {
  
}
