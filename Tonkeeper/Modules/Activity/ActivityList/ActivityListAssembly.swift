//
//  ActivityListAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 20.7.23..
//

import Foundation
import WalletCoreKeeper

struct ActivityListAssembly {
  static func module(activityListController: ActivityListController,
                     transactionBuilder: ActivityListTransactionBuilder,
                     transactionsEventDaemon: TransactionsEventDaemon,
                     output: ActivityListModuleOutput?) -> Module<ActivityListViewController, ActivityListModuleInput> {
    let presenter = ActivityListPresenter(activityListController: activityListController,
                                          transactionBuilder: transactionBuilder,
                                          transactionsEventDaemon: transactionsEventDaemon)
    
    let viewController = ActivityListViewController(presenter: presenter)
    
    presenter.viewInput = viewController
    presenter.output = output
    
    return Module(view: viewController, input: presenter)
  }
}
