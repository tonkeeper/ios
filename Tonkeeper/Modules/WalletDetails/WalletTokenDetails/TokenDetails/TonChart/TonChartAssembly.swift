//
//  TonChartAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 15.8.23..
//

import UIKit
import WalletCore

struct TonChartAssembly {
  static func module(walletProvider: WalletProvider,
                     chartController: ChartController,
                     output: TonChartModuleOutput) -> Module<TonChartViewController, TonChartModuleInput> {
    let presenter = TonChartPresenter(walletProvider: walletProvider, chartController: chartController)
    presenter.output = output
    
    let viewController = TonChartViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
