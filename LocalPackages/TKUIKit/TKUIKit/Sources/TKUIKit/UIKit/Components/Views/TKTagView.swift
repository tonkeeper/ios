import UIKit

public final class TKTagView: UIView, ConfigurableView {
  
  struct Layout {
    let titleFrame: CGRect
  }
  
  let titleLabel = UILabel()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public  init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let titleTargetSize = bounds.size.inset(by: .titlePadding)
    let titleFittingSize = titleLabel.systemLayoutSizeFitting(titleTargetSize)
    let titleSize = CGSize(width: min(titleTargetSize.width, titleFittingSize.width), height: titleFittingSize.height)
    titleLabel.frame = CGRect(origin: CGPoint(x: UIEdgeInsets.titlePadding.left, y: UIEdgeInsets.titlePadding.top), 
                              size: titleSize)
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let titleTargetSize = bounds.size.inset(by: .titlePadding)
    let titleFittingSize = titleLabel.systemLayoutSizeFitting(titleTargetSize)
    let titleSize = CGSize(width: min(titleTargetSize.width, titleFittingSize.width), height: titleFittingSize.height)
    return CGSize(width: UIEdgeInsets.titlePadding.left + titleSize.width, height: UIEdgeInsets.titlePadding.top + titleFittingSize.height)
  }

  public override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
    let titleTargetSize = targetSize.inset(by: .titlePadding)
    let titleSize = titleLabel.systemLayoutSizeFitting(titleTargetSize)
    return titleSize.padding(by: .titlePadding)
  }
  
  public struct Model {
    let title: NSAttributedString
    
    public init(title: NSAttributedString) {
      self.title = title
    }
    
    public init(title: String) {
      self.title = title.withTextStyle(.body4, color: .Text.secondary, alignment: .center, lineBreakMode: .byTruncatingTail)
    }
  }
  
  public func configure(model: Model) {
    titleLabel.attributedText = model.title
  }
}

private extension TKTagView {
  func setup() {
    backgroundColor = .Background.contentTint
    layer.cornerRadius = .cornerRadius
    
    addSubview(titleLabel)
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 4
}

private extension UIEdgeInsets {
  static var titlePadding: UIEdgeInsets {
    UIEdgeInsets(top: 2.5, left: 5, bottom: 3.5, right: 5)
  }
}


public extension CGSize {
  func inset(by insets: UIEdgeInsets) -> CGSize {
    CGSize(width: width - insets.left - insets.right, height: height - insets.top - insets.bottom)
  }
  
  func padding(by paddings: UIEdgeInsets) -> CGSize {
    CGSize(width: width + paddings.left + paddings.right, height: height + paddings.top + paddings.bottom)
  }
}
