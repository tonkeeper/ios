import UIKit
import TKUIKit

final class TwoLinesListItemView: UIView, ConfigurableView, ReusableView {
  
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let titleSize = titleLabel.sizeThatFits(.zero)
    titleLabel.frame = CGRect(
      origin: .zero,
      size: titleSize
    )
  
    let subtitleSize = subtitleLabel.sizeThatFits(CGSize(width: bounds.width, height: 0))
    subtitleLabel.frame = CGRect(
      origin: CGPoint(x: 0, y: titleLabel.frame.maxY),
      size: subtitleSize
    )
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let titleSize = titleLabel.sizeThatFits(.zero)
    let subtitleSize = subtitleLabel.sizeThatFits(CGSize(width: size.width, height: 0))
    return CGSize(width: size.width, height: titleSize.height + subtitleSize.height)
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
      self.title = title
      self.subtitle = subtitle
    }
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title.withTextStyle(.label1, color: .Text.primary)
    subtitleLabel.attributedText = model.subtitle?.withTextStyle(.body2, color: .Text.secondary)
    setNeedsLayout()
  }
}

private extension TwoLinesListItemView {
  func setup() {
    subtitleLabel.numberOfLines = 0
    
    addSubview(titleLabel)
    addSubview(subtitleLabel)
  }
}
