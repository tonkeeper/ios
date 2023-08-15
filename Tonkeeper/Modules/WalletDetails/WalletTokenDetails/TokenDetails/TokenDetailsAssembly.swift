//
//  TokenDetailsAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 13.7.23..
//

import UIKit
import WalletCore

struct TokenDetailsAssembly {
  static func module(output: TokenDetailsModuleOutput,
                     activityListModule: Module<ActivityListViewController, ActivityListModuleInput>,
                     tokenDetailsController: WalletCore.TokenDetailsController,
                     imageLoader: ImageLoader) -> Module<UIViewController, TokenDetailsModuleInput> {
    let presenter = TokenDetailsPresenter(tokenDetailsController: tokenDetailsController)
    presenter.output = output
    
    let viewController = TokenDetailsViewController(presenter: presenter,
                                                    listContentViewController: activityListModule.view,
                                                    imageLoader: imageLoader)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}

