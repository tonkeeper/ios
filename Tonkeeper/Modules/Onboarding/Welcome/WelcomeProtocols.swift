//
//  WelcomeWelcomeProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import Foundation

protocol WelcomeModuleOutput: AnyObject {
  func didTapContinueButton()
}

protocol WelcomeModuleInput: AnyObject {}

protocol WelcomePresenterInput {
  func viewDidLoad()
  func didTapContinueButton()
}

protocol WelcomeViewInput: AnyObject {
  func update(with model: WelcomeView.Model)
}
