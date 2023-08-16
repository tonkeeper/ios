//
//  TonChartAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 15.8.23..
//

import UIKit
import WalletCore

struct TonChartAssembly {
  static func module(chartController: ChartController,
                     output: TonChartModuleOutput) -> Module<TonChartViewController, TonChartModuleInput> {
    let presenter = TonChartPresenter(chartController: chartController)
    presenter.output = output
    
    let viewController = TonChartViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
