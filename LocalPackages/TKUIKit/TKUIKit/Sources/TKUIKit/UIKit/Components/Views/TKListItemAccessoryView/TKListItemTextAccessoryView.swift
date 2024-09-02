import UIKit

public final class TKListItemTextAccessoryView: UIView {
  
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
  
  private let label = UILabel()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let sizeThatFits = label.sizeThatFits(.zero)
    label.frame = CGRect(x: 0, y: 0, width: sizeThatFits.width, height: bounds.height)
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let sizeThatFits = label.sizeThatFits(.zero)
    return CGSize(width: sizeThatFits.width + 16, height: sizeThatFits.height)
  }
  
  private func setup() {
    addSubview(label)
    
    didUpdateConfiguration()
  }
  
  private func didUpdateConfiguration() {
    label.attributedText = configuration.text
    label.numberOfLines = configuration.numberOfLines
  }
}
