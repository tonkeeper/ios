//
//  TokenDetailsAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 13.7.23..
//

import UIKit

struct TokenDetailsAssembly {
  static func module(output: TokenDetailsModuleOutput) -> Module<UIViewController, Void> {
    let presenter = TokenDetailsPresenter()
    presenter.output = output
    
    let viewController = TokenDetailsViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
}

