//
//  ActivityTransactionDetailsAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 20.7.23..
//

import Foundation
import WalletCoreKeeper
import TKCore

struct ActivityTransactionDetailsAssembly {
  static func module(activityEventDetailsController: ActivityEventDetailsController,
                     urlOpener: URLOpener,
                     output: ActivityTransactionDetailsModuleOutput?) -> Module<ActivityTransactionDetailsViewController, ActivityTransactionDetailsModuleInput> {
    let presenter = ActivityTransactionDetailsPresenter(activityEventDetailsController: activityEventDetailsController, urlOpener: urlOpener)
    let viewController = ActivityTransactionDetailsViewController(presenter: presenter)
    
    presenter.viewInput = viewController
    presenter.output = output
    
    return Module(view: viewController, input: presenter)
  }
}
