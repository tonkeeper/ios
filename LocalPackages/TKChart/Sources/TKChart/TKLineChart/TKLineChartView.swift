import UIKit
import TKUIKit
import DGCharts

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
  
  public enum ChartMode {
    case linear
    case stepped
  }
  
  public struct ChartData {
    public let mode: ChartMode
    public let coordinates: [Coordinate]
    
    public init(mode: ChartMode, coordinates: [Coordinate]) {
      self.mode = mode
      self.coordinates = coordinates
    }
  }
  
  public var didSelectValue: ((Int) -> Void)?
  public var didDeselectValue: (() -> Void)?
  public var didStartDragging: (() -> Void)?
  public var didEndDragging: (() -> Void)?
  
  private var selectedValueIndex: Int?
  
  public var padding: UIEdgeInsets = .zero {
    didSet {
      chartView.setExtraOffsets(
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom
      )
    }
  }
  
  private let chartView = ChartView()
  private let verticalHighlightIndicatorView = UIView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public func getImage(transparent: Bool) -> UIImage? {
    chartView.getChartImage(transparent: transparent)
  }
  
  public func setChartData(_ chartData: ChartData) {
    let entries = chartData.coordinates.map {
      ChartDataEntry(x: $0.x, y: $0.y)
    }
    let gradient = CGGradient.with(easing: .easeInQuad, from: .Accent.blue, to: .clear)
    let dataSet = LineChartDataSet(entries: entries)
    dataSet.circleRadius = 0
    dataSet.setColor(.Accent.blue)
    dataSet.drawValuesEnabled = false
    dataSet.lineWidth = 2
    dataSet.fillAlpha = 0.24
    dataSet.fill = LinearGradientFill(gradient: gradient, angle: 270)
    dataSet.drawFilledEnabled = true
    dataSet.drawHorizontalHighlightIndicatorEnabled = false
    dataSet.drawVerticalHighlightIndicatorEnabled = false
    dataSet.highlightColor = .Accent.blue
    dataSet.highlightLineWidth = 1
    switch chartData.mode {
    case .linear:
      dataSet.mode = .linear
    case .stepped:
      dataSet.mode = .stepped
    }
    chartView.data = LineChartData(dataSet: dataSet)
  }
  
  func getPointsY(xArray: [CGFloat]) -> [CGPoint] {
    return xArray.map { CGPoint(x: $0, y: 0) }
      .map { point in chartView.valueForTouchPoint(point: point, axis: .left) }
      .map { value in chartView.pixelForValues(x: value.x, y: value.y, axis: .left) }
  }
  
  private func setup() {
    setupChartView()
    addSubview(chartView)
    
    chartView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      chartView.topAnchor.constraint(equalTo: topAnchor),
      chartView.leftAnchor.constraint(equalTo: leftAnchor),
      chartView.bottomAnchor.constraint(equalTo: bottomAnchor),
      chartView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
    
    let longTapGesture = UILongPressGestureRecognizer(
      target: self,
      action: #selector(longPressGestureHandler(gestureRecognizer:))
    )
    longTapGesture.minimumPressDuration = 0.3
    addGestureRecognizer(longTapGesture)
  }
  
  private func setupChartView() {
    chartView.isOpaque = false
    chartView.noDataText = ""
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
    chartView.gridBackgroundColor = .cyan
    
    chartView.addSubview(verticalHighlightIndicatorView)
    verticalHighlightIndicatorView.backgroundColor = .Accent.blue
    verticalHighlightIndicatorView.isHidden = true
  }
  
  @objc
  func longPressGestureHandler(gestureRecognizer: UILongPressGestureRecognizer) {
    switch gestureRecognizer.state {
    case .began, .changed:
      didStartDragging?()
      let point = gestureRecognizer.location(in: gestureRecognizer.view)
      guard let entry = chartView.getEntryByTouchPoint(point: point),
            let highlight = chartView.getHighlightByTouchPoint(point),
            let dataSet = chartView.data?.dataSets[highlight.dataSetIndex] else { return }
      let entryPoint = chartView.getPosition(entry: entry, axis: .left)
      verticalHighlightIndicatorView.frame = CGRect(
        x: entryPoint.x,
        y: 0,
        width: 1,
        height: chartView.frame.height
      )
      verticalHighlightIndicatorView.isHidden = false
      chartView.highlightValue(highlight)
      let index = dataSet.entryIndex(entry: entry)
      if selectedValueIndex != index || selectedValueIndex == nil {
        selectedValueIndex = index
        didSelectValue?(index)
      }
    case .cancelled, .ended, .failed:
      selectedValueIndex = nil
      verticalHighlightIndicatorView.isHidden = true
      didEndDragging?()
      chartView.highlightValue(nil)
      didDeselectValue?()
    default: break
    }
  }
}

extension TKLineChartView: ChartViewDelegate {}
