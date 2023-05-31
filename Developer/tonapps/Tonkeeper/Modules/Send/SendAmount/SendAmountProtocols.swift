//
//  SendAmountSendAmountProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation

protocol SendAmountModuleOutput: AnyObject {}

protocol SendAmountModuleInput: AnyObject {}

protocol SendAmountPresenterInput {
  func viewDidLoad()
}

protocol SendAmountViewInput: AnyObject {}