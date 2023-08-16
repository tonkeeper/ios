//
//  TonChartTonChartProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 15/08/2023.
//

import Foundation
import DGCharts

protocol TonChartModuleOutput: AnyObject {}

protocol TonChartModuleInput: AnyObject {}

protocol TonChartPresenterInput {
  func viewDidLoad()
}

protocol TonChartViewInput: AnyObject {
  func updateChart(with data: LineChartData)
}
