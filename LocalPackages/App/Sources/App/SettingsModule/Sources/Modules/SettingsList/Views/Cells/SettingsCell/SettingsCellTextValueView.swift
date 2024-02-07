import UIKit
import TKUIKit

final class SettingsCellTextValueView: UIView, ConfigurableView, ReusableView {
  
  private let label = UILabel()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public  init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    label.frame = bounds
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    label.sizeThatFits(size)
  }
  
  public func prepareForReuse() {
    label.attributedText = nil
  }

  public struct Model {
    public let text: NSAttributedString
    
    init(text: String) {
      self.text = text.withTextStyle(
        .label1,
        color: .Accent.blue,
        alignment: .right,
        lineBreakMode: .byTruncatingTail
      )
    }
  }
  
  public func configure(model: Model) {
    label.attributedText = model.text
  }
}

private extension SettingsCellTextValueView {
  func setup() {
    addSubview(label)
  }
}

