import UIKit

public final class TKUIListItemTextAccessoryView: UIView, TKConfigurableView {
  let textLabel = UILabel()

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Configuration: Hashable {
    public let text: NSAttributedString
    
    public init(text: NSAttributedString) {
      self.text = text
    }
  }
  
  public func configure(configuration: Configuration) {
    textLabel.attributedText = configuration.text
    setNeedsLayout()
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    textLabel.sizeThatFits(size)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    textLabel.frame = bounds
  }
}

private extension TKUIListItemTextAccessoryView {
  func setup() {
    addSubview(textLabel)
  }
}
