//
//  ActivityListAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 20.7.23..
//

import Foundation
import WalletCore

struct ActivityListAssembly {
  static func module(activityListController: ActivityListController,
                     transactionBuilder: ActivityListTransactionBuilder,
                     output: ActivityListModuleOutput?) -> Module<ActivityListViewController, ActivityListModuleInput> {
    let presenter = ActivityListPresenter(activityListController: activityListController,
                                          transactionBuilder: transactionBuilder)
    
    let viewController = ActivityListViewController(presenter: presenter)
    
    presenter.viewInput = viewController
    presenter.output = output
    
    return Module(view: viewController, input: presenter)
  }
}
