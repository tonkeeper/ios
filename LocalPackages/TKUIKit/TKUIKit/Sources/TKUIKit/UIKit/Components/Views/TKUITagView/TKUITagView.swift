import UIKit

public final class TKUITagView: UIView, TKConfigurableView {
  
  let label = UILabel()
  let colorView = UIView()
  
  public struct Configuration: Hashable {
    public let text: String
    public let textColor: UIColor
    public let backgroundColor: UIColor
    
    public init(text: String, textColor: UIColor, backgroundColor: UIColor) {
      self.text = text
      self.textColor = textColor
      self.backgroundColor = backgroundColor
    }
  }
  
  public func configure(configuration: Configuration) {
    label.text = configuration.text.uppercased()
    label.textColor = configuration.textColor
    colorView.backgroundColor = configuration.backgroundColor
    setNeedsLayout()
    invalidateIntrinsicContentSize()
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override var intrinsicContentSize: CGSize {
    sizeThatFits(CGSize(width: CGFloat.infinity, height: 0))
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let labelSizeThatFits = label.sizeThatFits(size)
    let fitWidth = labelSizeThatFits.width + UIEdgeInsets.textPadding.left + UIEdgeInsets.textPadding.right + .leftPadding
    let width = min(fitWidth, size.width)
    let height = TKTextStyle.body4.lineHeight + UIEdgeInsets.textPadding.top + UIEdgeInsets.textPadding.bottom
    return CGSize(width: width, height: height)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let colorViewFrame = CGRect(
      x: .leftPadding,
      y: 0,
      width: bounds.width - .leftPadding,
      height: bounds.height
    )
    
    let labelWidth = bounds.width - .leftPadding - UIEdgeInsets.textPadding.left - UIEdgeInsets.textPadding.right
    let labelHeight = bounds.height - UIEdgeInsets.textPadding.top - UIEdgeInsets.textPadding.bottom
    let labelFrame = CGRect(
      x: UIEdgeInsets.textPadding.left,
      y: UIEdgeInsets.textPadding.top,
      width: labelWidth,
      height: labelHeight
    )
    
    colorView.frame = colorViewFrame
    label.frame = labelFrame
  }
}

private extension TKUITagView {
  func setup() {
    label.font = TKTextStyle.body4.font
    
    colorView.layer.cornerRadius = .cornerRadius
    
    addSubview(colorView)
    colorView.addSubview(label)
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 4
  static let leftPadding: CGFloat = 6
}

private extension UIEdgeInsets {
  static var textPadding: UIEdgeInsets {
    UIEdgeInsets(top: 2.5, left: 5, bottom: 3.5, right: 5)
  }
}

