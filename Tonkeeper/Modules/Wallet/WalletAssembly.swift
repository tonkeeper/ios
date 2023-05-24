//
//  WalletAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class WalletAssembly {
  func walletRootModule(output: WalletRootModuleOutput) -> Module<UIViewController, Void> {
    let presenter = WalletRootPresenter()
    let viewController = WalletRootViewController(presenter: presenter)
    presenter.viewInput = viewController
    return Module(view: viewController, input: Void())
  }
}
