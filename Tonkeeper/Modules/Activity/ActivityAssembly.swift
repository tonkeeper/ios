//
//  ActivityAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

struct ActivityAssembly {
  
  func activityRootModule(output: ActivityRootModuleOutput) -> Module<UIViewController, Void> {
    let presenter = ActivityRootPresenter()
    presenter.output = output
    
    let viewController = ActivityRootViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
}
