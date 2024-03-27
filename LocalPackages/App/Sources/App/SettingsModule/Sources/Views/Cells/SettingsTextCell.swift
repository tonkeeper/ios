import UIKit
import TKUIKit

final class SettingsTextCell: UICollectionViewCell {
  var padding: UIEdgeInsets = .zero
  
  let textLabel = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    textLabel.frame = bounds.inset(by: padding)
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let width = size.width - padding.left - padding.right
    let textSize = textLabel.tkSizeThatFits(width)
    return CGSize(
      width: size.width,
      height: textSize.height + padding.top + padding.bottom
    )
  }
  
  struct Model: Identifiable, Hashable {
    let id: String
    let padding: UIEdgeInsets
    let text: NSAttributedString?
    let numberOfLines: Int
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }
  }
  
  func configure(model: Model) {
    self.padding = model.padding
    textLabel.attributedText = model.text
    textLabel.numberOfLines = model.numberOfLines
    setNeedsLayout()
  }
}

private extension SettingsTextCell {
  func setup() {
    addSubview(textLabel)
  }
}
