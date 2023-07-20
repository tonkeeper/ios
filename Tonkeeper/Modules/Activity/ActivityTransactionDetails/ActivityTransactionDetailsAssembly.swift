//
//  ActivityTransactionDetailsAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 20.7.23..
//

import Foundation

struct ActivityTransactionDetailsAssembly {
  static func module(output: ActivityTransactionDetailsModuleOutput?) -> Module<ActivityTransactionDetailsViewController, ActivityTransactionDetailsModuleInput> {
    let presenter = ActivityTransactionDetailsPresenter()
    let viewController = ActivityTransactionDetailsViewController(presenter: presenter)
    
    presenter.viewInput = viewController
    presenter.output = output
    
    return Module(view: viewController, input: presenter)
  }
}
