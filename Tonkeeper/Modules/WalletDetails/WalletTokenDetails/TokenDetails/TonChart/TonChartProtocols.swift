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
  func didSelectChartValue(at index: Int)
  func didDeselectChartValue()
}

protocol TonChartViewInput: AnyObject {
  func updateButtons(with model: TonChartButtonsView.Model)
  func updateHeader(with model: TonChartHeaderView.Model)
  func selectButton(at index: Int)
  func updateChart(with data: LineChartData)
}
