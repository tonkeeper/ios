//
//  PasscodeAuthCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 10.7.23..
//

import UIKit
import WalletCore

protocol PasscodeAuthCoordinatorOutput: AnyObject {
  func createPasscodeCoordinatorDidAuth(_ coordinator: PasscodeAuthCoordinator)
}

final class PasscodeAuthCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: PasscodeAuthCoordinatorOutput?
  
  let assembly: PasscodeAssembly
  
  init(router: NavigationRouter,
       assembly: PasscodeAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
  
  override func start() {
    openPasscodeAuth()
  }
}

private extension PasscodeAuthCoordinator {
  func openPasscodeAuth(){
    let configurator = assembly.passcodeAuthConfigurator()
    configurator.didFinish = { [weak self] _ in
      guard let self = self else { return }
      self.output?.createPasscodeCoordinatorDidAuth(self)
    }
    configurator.didFailed = {}
    
    let module = assembly.passcodeInputAssembly(output: self, configurator: configurator)
    initialPresentable = module.view
    router.setPresentables([(module.view, nil)])
  }
}

// MARK: - PasscodeInputModuleOutput

extension PasscodeAuthCoordinator: PasscodeInputModuleOutput {
  
}
