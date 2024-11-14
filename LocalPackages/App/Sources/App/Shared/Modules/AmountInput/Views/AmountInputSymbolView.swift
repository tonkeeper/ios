import UIKit
import TKUIKit

final class AmountInputSymbolView: UIView {
  struct Configuration {
    enum Item {
      case text(NSAttributedString)
      case icon(icon: UIImage, size: CGSize, tintColor: UIColor)
    }
    
    let item: Item
    let verticalOffset: CGFloat
  }
  
  var configuration: Configuration? {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  private let label = UILabel()
  private let imageView = UIImageView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    if let configuration {
      switch configuration.item {
      case .text:
        let size = label.intrinsicContentSize
        label.frame = CGRect(origin: CGPoint(x: bounds.midX - size.width/2,
                                             y: bounds.midY - size.height/2 + configuration.verticalOffset),
                             size: label.intrinsicContentSize)
      case let .icon(_, size, _):
        imageView.frame = CGRect(origin: CGPoint(x: bounds.midX - size.width/2,
                                                 y: bounds.midY - size.height/2 + configuration.verticalOffset),
                                 size: size)
      }
    } else {
      label.frame = .zero
      imageView.frame = .zero
    }
  }
  
  override var intrinsicContentSize: CGSize {
    switch configuration?.item {
    case .text:
      return label.intrinsicContentSize
    case let .icon(_, size, _):
      return size
    case nil:
      return .zero
    }
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    intrinsicContentSize
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    didUpdateConfiguration()
  }
  
  private func didUpdateConfiguration() {
    label.removeFromSuperview()
    imageView.removeFromSuperview()
    switch configuration?.item {
    case .text(let text):
      addSubview(label)
      label.attributedText = text
      imageView.image = nil
    case let .icon(icon, _, tintColor):
      addSubview(imageView)
      label.attributedText = nil
      imageView.image = icon
      imageView.tintColor = tintColor
    case nil:
      break
    }
  }
}
