//
//  PasscodeAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 29.6.23..
//

import Foundation

final class PasscodeAssembly {

  func passcodeInputAssembly(
    output: PasscodeInputModuleOutput
  ) -> Module<PasscodeInputViewController, Void> {
    return PasscodeInputAssembly.create(output: output)
  }
}
