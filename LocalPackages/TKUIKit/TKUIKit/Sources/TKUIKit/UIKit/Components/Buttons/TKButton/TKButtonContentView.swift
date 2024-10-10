import UIKit

class TKButtonContentView: UIView {
  
  var iconPosition: TKButtonIconPosition = .left {
    didSet { invalidateIntrinsicContentSize() }
  }
  
  var padding: UIEdgeInsets = .zero {
    didSet { invalidateIntrinsicContentSize() }
  }
  
  var spacing: CGFloat = 0 {
    didSet { invalidateIntrinsicContentSize() }
  }
  
  var cornerRadius: CGFloat = 0 {
    didSet {
      layer.cornerRadius = cornerRadius
    }
  }
  
  var title: NSAttributedString? {
    didSet {
      titleLabel.attributedText = title
      invalidateIntrinsicContentSize()
    }
  }
  
  var icon: UIImage?  {
    didSet {
      imageView.image = icon
      invalidateIntrinsicContentSize()
    }
  }
  
  var iconTintColor: UIColor = .clear {
    didSet {
      imageView.tintColor = iconTintColor
    }
  }
  
  let titleLabel = UILabel()
  let imageView = UIImageView()
  let contentContainerView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    let titleIntrinsicContentSize = titleLabel.intrinsicContentSize
    let imageIntrinsicContentSize = imageView.tkIntrinsicContentSize
    
    let spacing = getSpacing()
    
    let width = titleIntrinsicContentSize.width + imageIntrinsicContentSize.width + spacing + padding.left + padding.right
    let height = max(titleIntrinsicContentSize.height, imageIntrinsicContentSize.height) + padding.top + padding.bottom
    return CGSize(width: width, height: height)
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let titleSizeThatFits = titleLabel.sizeThatFits(bounds.size)
    let imageSizeThatFits = imageView.sizeThatFits(bounds.size)
    
    let spacing = getSpacing()
    
    let width = titleSizeThatFits.width + imageSizeThatFits.width + spacing + padding.left + padding.right
    let height = max(titleSizeThatFits.height, imageSizeThatFits.height) + padding.top + padding.bottom
    return CGSize(width: width, height: height)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let spacing = getSpacing()
    
    let availableWidth = bounds.width - padding.left - padding.right
    let availableHeight = bounds.height - padding.top - padding.bottom
    
    let titleSizeThatFits = titleLabel.sizeThatFits(bounds.size)
    let imageSizeThatFits = imageView.sizeThatFits(bounds.size)
    
    let imageViewWidth = min(availableWidth, imageSizeThatFits.width)
    let imageViewHeight = min(availableHeight, imageSizeThatFits.height)
    
    let titleWidth = availableWidth - imageViewWidth - spacing
    let titleHeigth = min(availableWidth - imageViewHeight, titleSizeThatFits.height)
    
    let imageViewX: CGFloat
    let titleX: CGFloat
    switch iconPosition {
    case .left:
      imageViewX = 0
      titleX = imageViewWidth + spacing
    case .right:
      imageViewX = titleWidth + spacing
      titleX = 0
    }
    
    let contentContainerViewFrame = CGRect(x: padding.left, y: padding.top, width: availableWidth, height: availableHeight)
    let imageViewFrame = CGRect(x: imageViewX, y: availableHeight/2 - imageViewHeight/2, width: imageViewWidth, height: imageViewHeight)
    let titleFrame = CGRect(x: titleX, y: availableHeight/2 - titleHeigth/2, width: titleWidth, height: titleHeigth)
    
    contentContainerView.frame = contentContainerViewFrame
    imageView.frame = imageViewFrame
    titleLabel.frame = titleFrame
  }
  
  override func setContentHuggingPriority(_ priority: UILayoutPriority, for axis: NSLayoutConstraint.Axis) {
    super.setContentHuggingPriority(priority, for: axis)
    contentContainerView.setContentHuggingPriority(priority, for: axis)
    titleLabel.setContentHuggingPriority(priority, for: axis)
    imageView.setContentHuggingPriority(priority, for: axis)
  }
  
  override func setContentCompressionResistancePriority(_ priority: UILayoutPriority, for axis: NSLayoutConstraint.Axis) {
    super.setContentCompressionResistancePriority(priority, for: axis)
    contentContainerView.setContentCompressionResistancePriority(priority, for: axis)
    titleLabel.setContentCompressionResistancePriority(priority, for: axis)
    imageView.setContentCompressionResistancePriority(priority, for: axis)
  }
}

private extension TKButtonContentView {
  func setup() {
    imageView.contentMode = .center
    imageView.tintColor = iconTintColor
    
    addSubview(contentContainerView)
    contentContainerView.addSubview(titleLabel)
    contentContainerView.addSubview(imageView)
  }
  
  func getSpacing() -> CGFloat {
    let hasTitle = !(titleLabel.text ?? "").isEmpty
    let hasImage = imageView.image != nil
    return hasTitle && hasImage ? spacing : 0
  }
}

public extension UIView {
  func tkSizeThatFits(_ width: CGFloat) -> CGSize {
    let sizeThatFits = self.sizeThatFits(CGSize(width: width, height: 0))
    return CGSize(width: min(width, sizeThatFits.width),
                  height: sizeThatFits.height)
  }
  func tkSizeThatFits(_ size: CGSize) -> CGSize {
    let sizeThatFits = self.sizeThatFits(size)
    return CGSize(width: min(size.width, sizeThatFits.width),
                  height: min(size.height, sizeThatFits.height))
  }
}

public extension UIImageView {
  var tkIntrinsicContentSize: CGSize {
    let intrinsicContentSize = self.intrinsicContentSize
    return CGSize(width: intrinsicContentSize.width >= 0 ? intrinsicContentSize.width : 0,
                  height: intrinsicContentSize.height >= 0 ? intrinsicContentSize.height : 0)
  }
}
