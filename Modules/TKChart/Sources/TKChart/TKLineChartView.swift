//
//  TKLineChartView.swift
//
//
//  Created by Grigory on 22.9.23..
//

import UIKit
import TKUIKit
import DGCharts

public protocol TKLineChartViewDelegate: AnyObject {
  func chartViewDidDeselectValue(_ chartView: TKLineChartView)
  func chartView(_ chartView: TKLineChartView, didSelectValueAt index: Int)
}

public protocol Coordinate {
  var x: Double { get }
  var y: Double { get }
}

public final class TKLineChartView: UIView {
  public enum Mode {
    case stepped
    case linear
  }
  
  public struct Data {
    public let coordinates: [Coordinate]
    public let mode: Mode
    
    public init(coordinates: [Coordinate], mode: Mode) {
      self.coordinates = coordinates
      self.mode = mode
    }
  }

  public weak var delegate: TKLineChartViewDelegate?
  
  private let chartView = LineChartView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public func setData(_ data: Data) {
    let chartEntries = data.coordinates.map { coordinate in
      ChartDataEntry(x: coordinate.x, y: coordinate.y)
    }

    let gradient = CGGradient.chartGradient()

    let dataSet = LineChartDataSet(entries: chartEntries)
    dataSet.circleRadius = 0
    dataSet.setColor(.Accent.blue)
    dataSet.drawValuesEnabled = false
    dataSet.lineWidth = 2
    dataSet.fillAlpha = 1
    dataSet.fill = LinearGradientFill(gradient: gradient, angle: 270)
    dataSet.drawFilledEnabled = true
    dataSet.drawHorizontalHighlightIndicatorEnabled = false
    dataSet.highlightColor = .Accent.blue
    dataSet.highlightLineWidth = 1
    
    switch data.mode {
    case .linear:
      dataSet.mode = .linear
    case .stepped:
      dataSet.mode = .stepped
    }
    
    chartView.data = LineChartData(dataSet: dataSet)
  }
  
  public func getChartImage(transparent: Bool) -> UIImage? {
    return chartView.getChartImage(transparent: transparent)
  }
}

private extension TKLineChartView {
  func setup() {
    setupChart()
    
    let longTapGesture = UILongPressGestureRecognizer(
      target: self,
      action: #selector(longPressGestureHandler(gestureRecognizer:))
    )
    longTapGesture.minimumPressDuration = 0.5
    addGestureRecognizer(longTapGesture)
    
    addSubview(chartView)
    chartView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      chartView.topAnchor.constraint(equalTo: topAnchor),
      chartView.leftAnchor.constraint(equalTo: leftAnchor),
      chartView.bottomAnchor.constraint(equalTo: bottomAnchor),
      chartView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
  
  func setupChart() {
    chartView.noDataText = ""
    chartView.drawGridBackgroundEnabled = false
    chartView.legend.enabled = false
    chartView.leftAxis.enabled = false
    chartView.rightAxis.enabled = false
    chartView.xAxis.enabled = false
    chartView.pinchZoomEnabled = false
    chartView.doubleTapToZoomEnabled = false
    chartView.scaleXEnabled = false
    chartView.scaleYEnabled = false
    chartView.dragYEnabled = false
    chartView.marker = ChartMarker()
    chartView.delegate = self
    chartView.highlightPerTapEnabled = false
    chartView.minOffset = 0
    chartView.backgroundColor = .Background.page
  }
  
  @objc
  func longPressGestureHandler(gestureRecognizer: UILongPressGestureRecognizer) {
    switch gestureRecognizer.state {
    case .began, .changed:
      let point = gestureRecognizer.location(in: gestureRecognizer.view)
      guard let entry = chartView.getEntryByTouchPoint(point: point),
            let highlight = chartView.getHighlightByTouchPoint(point),
            let dataSet = chartView.data?.dataSets[highlight.dataSetIndex]else { return }
      let index = dataSet.entryIndex(entry: entry)
      chartView.highlightValue(highlight)
      delegate?.chartView(self, didSelectValueAt: index)
    case .cancelled, .ended, .failed:
      chartView.highlightValue(nil)
    default: break
    }
  }
}

// MARK: - ChartViewDelegate

extension TKLineChartView: ChartViewDelegate {
  public func chartViewDidEndPanning(_ chartView: ChartViewBase) {
    chartView.highlightValue(nil)
    delegate?.chartViewDidDeselectValue(self)
  }
  
  public func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
    guard let dataSet = chartView.data?.dataSets[highlight.dataSetIndex] else { return }
    let index = dataSet.entryIndex(entry: entry)
    delegate?.chartView(self, didSelectValueAt: index)
  }
}
