import UIKit
import TKUIKit
import DGCharts

public final class TKLineChartFullView: UIView, ConfigurableView {
  
  public var didSelectValue: ((Int) -> Void)?
  public var didDeselectValue: (() -> Void)?
  
  let chartView = TKLineChartView()
  let maximumLabel = UILabel()
  let minimumLabel = UILabel()
  let xAxisLeftLabel = UILabel()
  let xAxisMiddleLabel = UILabel()
  let substrateView = ChartSubstrateView()
    
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Model {
    public let chartData: TKLineChartView.ChartData
    public let maximumValue: String
    public let minimumValue: String
    public let xAxisLeftValue: String
    public let xAxisMiddleValue: String
    
    public init(chartData: TKLineChartView.ChartData,
                maximumValue: String,
                minimumValue: String,
                xAxisLeftValue: String,
                xAxisMiddleValue: String) {
      self.chartData = chartData
      self.maximumValue = maximumValue
      self.minimumValue = minimumValue
      self.xAxisLeftValue = xAxisLeftValue
      self.xAxisMiddleValue = xAxisMiddleValue
    }
  }
  
  public func configure(model: Model) {
    chartView.setChartData(model.chartData)
    maximumLabel.attributedText = model.maximumValue.withTextStyle(
      .minMaxTextStyle,
      color: .Text.secondary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    ).replaceMonospaceSpaces()
    minimumLabel.attributedText = model.minimumValue.withTextStyle(
      .minMaxTextStyle,
      color: .Text.secondary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    ).replaceMonospaceSpaces()
    substrateView.configure(
      model: ChartSubstrateView.Model(
        leftValue: model.xAxisLeftValue,
        middleValue: model.xAxisMiddleValue
      )
    )

    setNeedsLayout()
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    xAxisLeftLabel.sizeToFit()
    xAxisLeftLabel.frame = CGRect(
      x: bounds.width / 10,
      y: bounds.height - xAxisLeftLabel.bounds.height,
      width: xAxisLeftLabel.bounds.width,
      height: xAxisLeftLabel.bounds.height
    )
    
    xAxisMiddleLabel.sizeToFit()
    xAxisMiddleLabel.frame = CGRect(
      x: bounds.width / 2,
      y: bounds.height - xAxisMiddleLabel.bounds.height,
      width: xAxisMiddleLabel.bounds.width,
      height: xAxisMiddleLabel.bounds.height
    )

    substrateView.frame = chartView.frame
  }
  
  private func setup() {
    addSubview(substrateView)
    addSubview(chartView)
    addSubview(maximumLabel)
    addSubview(minimumLabel)
    
    chartView.padding.bottom = 30

    chartView.translatesAutoresizingMaskIntoConstraints = false
    maximumLabel.translatesAutoresizingMaskIntoConstraints = false
    minimumLabel.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      chartView.leftAnchor.constraint(equalTo: leftAnchor),
      chartView.bottomAnchor.constraint(equalTo: bottomAnchor),
      chartView.rightAnchor.constraint(equalTo: rightAnchor),
      chartView.heightAnchor.constraint(equalToConstant: 180),
      
      maximumLabel.topAnchor.constraint(equalTo: topAnchor),
      maximumLabel.bottomAnchor.constraint(equalTo: chartView.topAnchor, constant: -.maximumLabelBottomInset),
      maximumLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: -.minMaxRightOffset),
      maximumLabel.heightAnchor.constraint(equalToConstant: .minMaxLabelHeight),
      
      minimumLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -.minimumLabelBottomInset),
      minimumLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: -.minMaxRightOffset),
      minimumLabel.heightAnchor.constraint(equalToConstant: .minMaxLabelHeight),
    ])
    
    chartView.didSelectValue = { [weak self] in
      self?.didSelectValue?($0)
    }
    chartView.didDeselectValue = { [weak self] in
      self?.didDeselectValue?()
    }
    
    chartView.didStartDragging = { [weak self] in
      self?.maximumLabel.isHidden = true
      self?.minimumLabel.isHidden = true
    }
    
    chartView.didEndDragging = { [weak self] in
      self?.maximumLabel.isHidden = false
      self?.minimumLabel.isHidden = false
    }
  }
}
private extension TKTextStyle {
  static var minMaxTextStyle: TKTextStyle {
    TKTextStyle(
      font: .monospacedSystemFont(ofSize: 12, weight: .medium),
      lineHeight: 12
    )
  }
}

private extension CGFloat {
  static let minMaxRightOffset: CGFloat = 16
}

private final class ChartGradientLineView: TKPassthroughView {
  override init(frame: CGRect) {
    super.init(frame: frame)
    isOpaque = false
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    let gradient = CGGradient.with(easing: .easeInQuad, from: .clear, to: .Accent.blue)
    let startPoint = CGPoint(x: rect.midX, y: rect.minY)
    let endPoint = CGPoint(x: rect.midX, y: rect.maxY)
    context.addRect(rect)
    context.clip()
    context.drawLinearGradient(
      gradient,
      start: startPoint,
      end: endPoint,
      options: CGGradientDrawingOptions())
  }
}

final class ChartSubstrateView: TKPassthroughView, ConfigurableView {
  
  private let leftLabel = UILabel()
  private let middleLabel = UILabel()
  
  private lazy var gradientLineViews: [ChartGradientLineView] = {
    (0..<5).map { _ in
      let view = ChartGradientLineView()
      view.alpha = 0.08
      return view
    }
  }()
  
  struct Model {
    let leftValue: String
    let middleValue: String
  }
  
  func configure(model: Model) {
    leftLabel.attributedText = model.leftValue.withTextStyle(
      .minMaxTextStyle,
      color: .Background.contentTint,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    middleLabel.attributedText = model.middleValue.withTextStyle(
      .minMaxTextStyle,
      color: .Background.contentTint,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    setNeedsLayout()
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    gradientLineViews.forEach { addSubview($0) }
    addSubview(leftLabel)
    addSubview(middleLabel)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    let offset: CGFloat = bounds.width / CGFloat(gradientLineViews.count)
    var xPosition = offset/2
    for gradientLineView in gradientLineViews {
      gradientLineView.frame = CGRect(
        x: xPosition,
        y: 0,
        width: 1,
        height: bounds.height
      )
      xPosition += offset
    }
    
    leftLabel.sizeToFit()
    leftLabel.frame.origin.x = offset/2 + 6
    leftLabel.frame.origin.y = bounds.height - leftLabel.frame.height - 2
    
    middleLabel.sizeToFit()
    middleLabel.frame.origin.x = offset/2 + (offset * 2) + 6
    middleLabel.frame.origin.y = bounds.height - middleLabel.frame.height - 2
  }
}

private extension CGFloat {
  static let minimumLabelBottomInset: CGFloat = 24
  static let maximumLabelBottomInset: CGFloat = 4
  static let minMaxLabelHeight: CGFloat = 16
}

extension NSAttributedString {
  func replaceMonospaceSpaces() -> NSAttributedString {
    let str = NSMutableAttributedString(attributedString: self)
    let regex = try? NSRegularExpression(pattern: " ", options: [])
    let range = NSMakeRange(0, str.string.count)
    guard let matches = regex?.matches(in: str.string, range: range) else {
      return str
    }
    
    for match in matches.reversed() {
      str.addAttributes([.font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)], range: match.range)
    }
    
    return str
  }
}
