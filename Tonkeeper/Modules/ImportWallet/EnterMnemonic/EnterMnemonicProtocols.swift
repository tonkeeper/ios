//
//  EnterMnemonicEnterMnemonicProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import Foundation

protocol EnterMnemonicModuleOutput: AnyObject {}

protocol EnterMnemonicModuleInput: AnyObject {}

protocol EnterMnemonicPresenterInput {
  func viewDidLoad()
}

protocol EnterMnemonicViewInput: AnyObject {}