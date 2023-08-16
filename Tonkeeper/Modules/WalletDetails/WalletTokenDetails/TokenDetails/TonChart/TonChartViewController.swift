//
//  TonChartTonChartViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 15/08/2023.
//

import UIKit
import DGCharts

class TonChartViewController: GenericViewController<TonChartView> {

  // MARK: - Module

  private let presenter: TonChartPresenterInput

  // MARK: - Init

  init(presenter: TonChartPresenterInput) {
    self.presenter = presenter
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    presenter.viewDidLoad()
  }
}

// MARK: - TonChartViewInput

extension TonChartViewController: TonChartViewInput {
  func updateChart(with data: LineChartData) {
    customView.chartView.data = data
  }
}

// MARK: - Private

private extension TonChartViewController {
  func setup() {
    setupChart()
  }
  
  func setupChart() {
    customView.chartView.drawGridBackgroundEnabled = false
    customView.chartView.legend.enabled = false
    customView.chartView.leftAxis.enabled = false
    customView.chartView.rightAxis.enabled = false
    customView.chartView.xAxis.enabled = false
    customView.chartView.pinchZoomEnabled = false
    customView.chartView.doubleTapToZoomEnabled = false
    customView.chartView.scaleXEnabled = false
    customView.chartView.scaleYEnabled = false
    customView.chartView.dragYEnabled = false
    customView.chartView.marker = TonChartMarker()
    customView.chartView.delegate = self
    customView.chartView.highlightPerTapEnabled = false
  }
}

extension TonChartViewController: ChartViewDelegate {
  func chartViewDidEndPanning(_ chartView: ChartViewBase) {
    chartView.highlightValue(nil)
  }
  
  func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {}
}
