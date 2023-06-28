//
//  OnboardingCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit

final class OnboardingCoordinator: Coordinator<NavigationRouter> {
  
  private let assembly: OnboardingAssembly
  
  init(router: NavigationRouter,
       assembly: OnboardingAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
  
  override func start() {
    openWelcome()
  }
}

private extension OnboardingCoordinator {
  func openWelcome() {
    let module = assembly.welcomeModule(output: self)
    router.setPresentables([(module.view, nil)])
  }
}

// MARK: - WelcomeModuleOutput

extension OnboardingCoordinator: WelcomeModuleOutput {}
