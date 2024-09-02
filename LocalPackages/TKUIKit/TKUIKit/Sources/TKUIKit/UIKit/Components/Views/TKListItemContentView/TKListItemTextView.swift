import UIKit

public final class TKListItemTextView: UIView {
  
  public struct Configuration {
    public let text: NSAttributedString?
    public let numberOfLines: Int
    public let padding: UIEdgeInsets
    
    public init(text: String? = nil,
                color: UIColor,
                textStyle: TKTextStyle,
                alignment: NSTextAlignment = .left,
                lineBreakMode: NSLineBreakMode = .byTruncatingTail,
                numberOfLines: Int = 1,
                padding: UIEdgeInsets = .zero) {
      self.text = text?.withTextStyle(
        textStyle,
        color: color,
        alignment: alignment,
        lineBreakMode: lineBreakMode
      )
      self.numberOfLines = numberOfLines
      self.padding = padding
    }
    
    public init(text: NSAttributedString?,
                numberOfLines: Int,
                padding: UIEdgeInsets) {
      self.text = text
      self.numberOfLines = numberOfLines
      self.padding = padding
    }
  }
  
  public var configuration = Configuration(text: "Label", color: .Text.primary, textStyle: .body2) {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  let textLabel = UILabel()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let labelFrame = CGRect(
      x: configuration.padding.left,
      y: configuration.padding.top,
      width: bounds.width - configuration.padding.left - configuration.padding.right,
      height: bounds.height - configuration.padding.top - configuration.padding.bottom
    )
    textLabel.frame = labelFrame
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let width = size.width - configuration.padding.left - configuration.padding.right
    let labelSizeThatFits = textLabel.sizeThatFits(CGSize(width: width, height: .zero))
    guard labelSizeThatFits != .zero else {
      return .zero
    }
    let labelWidth = min(labelSizeThatFits.width, size.width)
    let resultWidth = labelWidth + configuration.padding.left + configuration.padding.right
    let resultHeight = labelSizeThatFits.height + configuration.padding.top + configuration.padding.bottom
    return CGSize(width: resultWidth, height: resultHeight)
  }
  
  public override var intrinsicContentSize: CGSize {
    sizeThatFits(CGSize(width: CGFloat.infinity, height: 0))
  }
  
  private func setup() {
    addSubview(textLabel)
    
    didUpdateConfiguration()
  }
  
  private func didUpdateConfiguration() {
    textLabel.attributedText = configuration.text
    textLabel.numberOfLines = configuration.numberOfLines
  }
}
