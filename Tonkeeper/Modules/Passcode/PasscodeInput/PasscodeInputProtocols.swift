//
//  PasscodeInputPasscodeInputProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/06/2023.
//

import Foundation

protocol PasscodeInputModuleOutput: AnyObject {}

protocol PasscodeInputModuleInput: AnyObject {}

protocol PasscodeInputPresenterInput {
  func viewDidLoad()
}

protocol PasscodeInputViewInput: AnyObject {}