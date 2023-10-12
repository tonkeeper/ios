//
//  OnboardingCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit

protocol OnboardingCoordinatorOutput: AnyObject {
  func onboardingCoordinatorDidTapGetStarted(_ coordinator: OnboardingCoordinator)
}

final class OnboardingCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: OnboardingCoordinatorOutput?
  
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
    router.setPresentables([(module.view, nil)], options: .init(isAnimated: false))
  }
}

// MARK: - WelcomeModuleOutput

extension OnboardingCoordinator: WelcomeModuleOutput {
  func didTapContinueButton() {
    output?.onboardingCoordinatorDidTapGetStarted(self)
  }
}
