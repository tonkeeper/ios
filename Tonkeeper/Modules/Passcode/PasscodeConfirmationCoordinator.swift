//
//  PasscodeConfirmationCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 10.10.23..
//

import UIKit
import WalletCore

protocol PasscodeConfirmationCoordinatorOutput: AnyObject {
  func passcodeConfirmationCoordinatorDidConfirm(_ coordinator: PasscodeConfirmationCoordinator)
  func passcodeConfirmationCoordinatorDidClose(_ coordinator: PasscodeConfirmationCoordinator)
}
final class PasscodeConfirmationCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: PasscodeConfirmationCoordinatorOutput?
  
  let assembly: PasscodeAssembly
  
  init(router: NavigationRouter,
       assembly: PasscodeAssembly) {
    self.assembly = assembly
    super.init(router: router)
    router.rootViewController.modalPresentationStyle = .fullScreen
    router.rootViewController.modalTransitionStyle = .crossDissolve
  }
  
  override func start() {
    openPasscode()
  }
}

private extension PasscodeConfirmationCoordinator {
  func openPasscode() {
    let configurator = assembly.passcodeAuthConfigurator()
    configurator.didFinish = { [weak self] _ in
      guard let self = self else { return }
      self.output?.passcodeConfirmationCoordinatorDidConfirm(self)
    }
    configurator.didFinishBiometry = { [weak self] isSuccess in
      guard let self = self else { return }
      if isSuccess {
        self.output?.passcodeConfirmationCoordinatorDidConfirm(self)
      } else {
        self.output?.passcodeConfirmationCoordinatorDidClose(self)
      }
    }
    
    let module = assembly.passcodeInputAssembly(output: self, configurator: configurator)
    module.view.setupCloseLeftButton { [weak self] in
      guard let self = self else { return }
      self.output?.passcodeConfirmationCoordinatorDidClose(self)
    }
    router.setPresentables([(module.view, nil)])
  }
}

// MARK: - PasscodeInputModuleOutput

extension PasscodeConfirmationCoordinator: PasscodeInputModuleOutput {}
