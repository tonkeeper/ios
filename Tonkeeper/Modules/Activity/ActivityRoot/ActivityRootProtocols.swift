//
//  ActivityRootActivityRootProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import Foundation

protocol ActivityRootModuleOutput: AnyObject {}

protocol ActivityRootModuleInput: AnyObject {}

protocol ActivityRootPresenterInput {
  func viewDidLoad()
}

protocol ActivityRootViewInput: AnyObject {}