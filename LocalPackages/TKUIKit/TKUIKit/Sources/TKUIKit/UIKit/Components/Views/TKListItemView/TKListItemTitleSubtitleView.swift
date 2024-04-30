import UIKit

public final class TKListItemTitleSubtitleView: UIView, ReusableView {
  let titleLabel = UILabel()
  let tagView = TKTagView()
  let subtitleLabel = UILabel()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public  init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let titleSize = titleLabel.tkSizeThatFits(size.width)
    let subtitleSize = subtitleLabel.tkSizeThatFits(size.width)
    
    let width = [titleSize.width, subtitleSize.width].max() ?? 0
    let height = titleSize.height + subtitleSize.height
    
    return CGSize(
      width: width,
      height: height
    )
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let subtitleSizeToFit = subtitleLabel.tkSizeThatFits(bounds.width)
    let subtitleSize = CGSize(width: bounds.width, height: subtitleSizeToFit.height)
    let subtitleOrigin = CGPoint(x: 0, y: bounds.height - subtitleSize.height)
    let subtitleFrame = CGRect(origin: subtitleOrigin, size: subtitleSize)
    
    let topWidth: CGFloat
    let tagViewSize: CGSize
    if !tagView.isHidden {
      let tagViewSizeToFit = tagView.systemLayoutSizeFitting(CGSize(width: bounds.width, height: 0))
      tagViewSize = tagViewSizeToFit
      topWidth = bounds.width - tagViewSizeToFit.width - .tagViewSpacing
    } else {
      topWidth = bounds.width
      tagViewSize = .zero
    }

    let titleSize = titleLabel.tkSizeThatFits(topWidth)
    let titleOrigin = CGPoint.zero
    let titleFrame = CGRect(origin: titleOrigin, size: titleSize)
    
    let tagViewOrigin = CGPoint(x: titleFrame.maxX + .tagViewSpacing, y: titleFrame.midY - tagViewSize.height/2)
    let tagViewFrame = CGRect(origin: tagViewOrigin, size: tagViewSize)
    
    titleLabel.frame = titleFrame
    tagView.frame = tagViewFrame
    subtitleLabel.frame = subtitleFrame
  }
  
  public struct Model {
    public let title: NSAttributedString?
    public let tagModel: TKTagView.Model?
    public let subtitle: NSAttributedString?
    
    public init(title: NSAttributedString?,
                tagModel: TKTagView.Model? = nil,
                subtitle: NSAttributedString?) {
      self.title = title
      self.tagModel = tagModel
      self.subtitle = subtitle
    }
  }
  
  public func configure(model: Model) {
    titleLabel.attributedText = model.title
    if let tagModel = model.tagModel {
      tagView.configure(model: tagModel)
      tagView.isHidden = false
    } else {
      tagView.isHidden = true
    }
    subtitleLabel.attributedText = model.subtitle
    setNeedsLayout()
  }
  
  public func prepareForReuse() {
    titleLabel.attributedText = nil
    subtitleLabel.attributedText = nil
  }
}

private extension TKListItemTitleSubtitleView {
  func setup() {
    titleLabel.numberOfLines = 1
    addSubview(titleLabel)
    addSubview(subtitleLabel)
    addSubview(tagView)
  }
}

private extension CGFloat {
  static let tagViewSpacing: CGFloat = 6
}
