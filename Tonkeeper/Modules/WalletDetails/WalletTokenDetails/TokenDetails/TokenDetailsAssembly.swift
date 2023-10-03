//
//  TokenDetailsAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 13.7.23..
//

import UIKit
import TKCore
import WalletCore

struct TokenDetailsAssembly {
  static func module(output: TokenDetailsModuleOutput,
                     activityListModule: Module<ActivityListViewController, ActivityListModuleInput>,
                     walletProvider: WalletProvider,
                     tokenDetailsController: WalletCore.TokenDetailsController,
                     imageLoader: ImageLoader,
                     urlOpener: URLOpener) -> Module<UIViewController, TokenDetailsModuleInput> {
    let presenter = TokenDetailsPresenter(
      walletProvider: walletProvider,
      tokenDetailsController: tokenDetailsController,
      urlOpener: urlOpener
    )
    presenter.output = output
    
    let viewController = TokenDetailsViewController(presenter: presenter,
                                                    listContentViewController: activityListModule.view,
                                                    imageLoader: imageLoader)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}

