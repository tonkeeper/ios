//
//  ActivityEmptyAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 20.7.23..
//

import Foundation

struct ActivityEmptyAssembly {
  static func module(output: ActivityEmptyModuleOutput?) -> Module<ActivityEmptyViewController, ActivityEmptyModuleInput> {
    let presenter = ActivityEmptyPresenter()
    let viewController = ActivityEmptyViewController(presenter: presenter)
    
    presenter.viewInput = viewController
    presenter.output = output
    
    return Module(view: viewController, input: presenter)
  }
}
