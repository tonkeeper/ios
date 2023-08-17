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
  func didSelectButton(at index: Int)
}

protocol TonChartViewInput: AnyObject {
  func updateButtons(with model: TonChartButtonsView.Model)
  func selectButton(at index: Int)
  func updateChart(with data: LineChartData)
}
