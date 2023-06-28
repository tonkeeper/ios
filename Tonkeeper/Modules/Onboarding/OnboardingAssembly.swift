//
//  OnboardingAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit

struct OnboardingAssembly {

  func welcomeModule(output: WelcomeModuleOutput) -> Module<UIViewController, Void> {
    let presenter = WelcomePresenter()
    presenter.output = output
    
    let viewController = WelcomeViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
}
