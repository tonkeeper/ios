//
//  TonChartTonChartPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 15/08/2023.
//

import UIKit
import WalletCore
import DGCharts

final class TonChartPresenter {
  
  // MARK: - Module
  
  weak var viewInput: TonChartViewInput?
  weak var output: TonChartModuleOutput?
  
  // MARK: - Dependencies
  
  private let chartController: ChartController
  
  // MARK: - State
  
  private var selectedPeriod: ChartController.Period = .hour
  
  init(chartController: ChartController) {
    self.chartController = chartController
  }
}

// MARK: - TonChartPresenterIntput

extension TonChartPresenter: TonChartPresenterInput {
  func viewDidLoad() {
    loadChartData()
  }
}

// MARK: - TonChartModuleInput

extension TonChartPresenter: TonChartModuleInput {}

// MARK: - Private

private extension TonChartPresenter {
  func loadChartData() {
    Task {
      do {
        let coordinates = try await chartController.getChartData(period: selectedPeriod)
        let chartData = prepareChartData(coordinates: coordinates, period: selectedPeriod)
        
        await MainActor.run {
          viewInput?.updateChart(with: chartData)
        }
      } catch {
        // TBD: show error on graphic
      }
    }
  }
  
  private func prepareChartData(coordinates: [Coordinate],
                                period: ChartController.Period) -> LineChartData {
    let chartEntries = coordinates.map { coordinate in
      ChartDataEntry(x: coordinate.x, y: coordinate.y)
    }
    
    let gradient = CGGradient.with(
      easing: Cubic.easeIn,
      between: UIColor.Background.page,
      and: UIColor.Accent.blue)
    
    let dataSet = LineChartDataSet(entries: chartEntries)
    dataSet.circleRadius = 0
    dataSet.setColor(.Accent.blue)
    dataSet.drawValuesEnabled = false
    dataSet.lineWidth = 2
    dataSet.fillAlpha = 1
    dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
    dataSet.drawFilledEnabled = true
    dataSet.drawHorizontalHighlightIndicatorEnabled = false
    dataSet.highlightColor = .Accent.blue
    dataSet.highlightLineWidth = 1
    
    switch period {
    case .hour:
      dataSet.mode = .stepped
    default:
      dataSet.mode = .linear
    }
  
    return LineChartData(dataSet: dataSet)
  }
}
