//
//  TonChartAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 15.8.23..
//

import UIKit

struct TonChartAssembly {
  static func module(output: TonChartModuleOutput) -> Module<TonChartViewController, TonChartModuleInput> {
    let presenter = TonChartPresenter()
    presenter.output = output
    
    let viewController = TonChartViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
