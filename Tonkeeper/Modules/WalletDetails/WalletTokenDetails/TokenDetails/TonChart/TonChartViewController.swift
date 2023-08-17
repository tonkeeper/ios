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
  func updateButtons(with model: TonChartButtonsView.Model) {
    customView.buttonsView.configure(model: model)
  }
  
  func updateHeader(with model: TonChartHeaderView.Model) {
    customView.headerView.configure(model: model)
  }
  
  func selectButton(at index: Int) {
    customView.buttonsView.selectButton(at: index)
  }
  
  func updateChart(with data: LineChartData) {
    customView.errorView.isHidden = true
    customView.chartView.isHidden = false
    customView.chartView.data = data
  }
  
  func showError(with model: TonChartErrorView.Model) {
    customView.errorView.isHidden = false
    customView.chartView.isHidden = true
    customView.errorView.configure(model: model)
  }
}

// MARK: - Private

private extension TonChartViewController {
  func setup() {
    setupChart()
    
    customView.buttonsView.didTapButton = { [weak self] index in
      self?.presenter.didSelectButton(at: index)
    }
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
    
    
    let longTapGesture = UILongPressGestureRecognizer(
      target: self,
      action: #selector(longPressGestureHandler(gestureRecognizer:))
    )
    longTapGesture.minimumPressDuration = 0.5
    customView.addGestureRecognizer(longTapGesture)
  }
}

extension TonChartViewController: ChartViewDelegate {
  func chartViewDidEndPanning(_ chartView: ChartViewBase) {
    chartView.highlightValue(nil)
    presenter.didDeselectChartValue()
  }
  
  func chartValueSelected(_ chartView: ChartViewBase, 
                          entry: ChartDataEntry,
                          highlight: Highlight) {
    guard let dataSet = chartView.data?.dataSets[highlight.dataSetIndex] else { return }
    let index = dataSet.entryIndex(entry: entry)
    presenter.didSelectChartValue(at: index)
    TapticGenerator.generateTapHeavyFeedback()
  }
  
  @objc
  func longPressGestureHandler(gestureRecognizer: UILongPressGestureRecognizer) {
    switch gestureRecognizer.state {
    case .began, .changed:
      let point = gestureRecognizer.location(in: gestureRecognizer.view)
      guard let entry = customView.chartView.getEntryByTouchPoint(point: point),
            let highlight = customView.chartView.getHighlightByTouchPoint(point),
            let dataSet = customView.chartView.data?.dataSets[highlight.dataSetIndex]else { return }
      let index = dataSet.entryIndex(entry: entry)
      customView.chartView.highlightValue(highlight)
      presenter.didSelectChartValue(at: index)
      TapticGenerator.generateTapHeavyFeedback()
    case .cancelled, .ended, .failed:
      customView.chartView.highlightValue(nil)
    default: break
    }
  }
}
