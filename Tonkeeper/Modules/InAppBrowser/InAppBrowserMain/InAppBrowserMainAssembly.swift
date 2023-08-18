//
//  InAppBrowserMainAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 18.8.23..
//

import UIKit
import WalletCore

struct InAppBrowserMainAssembly {
  static func module(output: InAppBrowserMainModuleOutput, url: URL) -> Module<UIViewController, InAppBrowserMainModuleInput> {
    let presenter = InAppBrowserMainPresenter(url: url)
    presenter.output = output
    
    let viewController = InAppBrowserMainViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}

