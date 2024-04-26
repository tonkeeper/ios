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

private class ChartView: LineChartView {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                         shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
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
  
  private let chartView = ChartView()
  private let maxLabel = UILabel()
  
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

//    maxLabel.text = "\(dataSet.yMax)"
    
    switch data.mode {
    case .linear:
      dataSet.mode = .linear
    case .stepped:
      dataSet.mode = .stepped
    }
    
    chartView.data = LineChartData(dataSet: dataSet)
    
    
    print(dataSet.entries[dataSet.entries.count/10].x)
//    print(dataSet.entries[dataSet.entries.count/2].x)
    
//    let point = CGPoint(x: 100, y: 100)
//    guard let entry = chartView.getEntryByTouchPoint(point: point),
//          let highlight = chartView.getHighlightByTouchPoint(point),
//          let dataSet = chartView.data?.dataSets[highlight.dataSetIndex] else { return }
//    print("dsd")
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
    longTapGesture.minimumPressDuration = 0.3
    addGestureRecognizer(longTapGesture)
    
//    maxLabel.textColor = .white
    
    addSubview(chartView)
//    addSubview(maxLabel)
    
//    maxLabel.snp.makeConstraints { make in
//      make.right.top.equalTo(chartView)
//    }
    
    maxLabel.translatesAutoresizingMaskIntoConstraints = false
    chartView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      chartView.topAnchor.constraint(equalTo: topAnchor),
      chartView.leftAnchor.constraint(equalTo: leftAnchor),
      chartView.bottomAnchor.constraint(equalTo: bottomAnchor),
      chartView.rightAnchor.constraint(equalTo: rightAnchor),
      
//      maxLabel.topAnchor.constraint(equalTo: chartView.topAnchor),
//      maxLabel.rightAnchor.constraint(equalTo: chartView.rightAnchor)
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
      print(point)
      guard let entry = chartView.getEntryByTouchPoint(point: point),
            let highlight = chartView.getHighlightByTouchPoint(point),
            let dataSet = chartView.data?.dataSets[highlight.dataSetIndex] else { return }
      print(Date(timeIntervalSince1970: entry.x))
      let index = dataSet.entryIndex(entry: entry)
      chartView.highlightValue(highlight)
      delegate?.chartView(self, didSelectValueAt: index)
    case .cancelled, .ended, .failed:
      chartView.highlightValue(nil)
      delegate?.chartViewDidDeselectValue(self)
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
