import UIKit

public final class TKTextWithTagView: UIView, ConfigurableView {
  let titleLabel = UILabel()
  let tagView = TKTagView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public  init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let titleFittingSize = titleLabel.systemLayoutSizeFitting(bounds.size)
    if tagView.isHidden {
      let titleSize = CGSize(width: min(bounds.width, titleFittingSize.width), height: titleFittingSize.height)
      titleLabel.frame = CGRect(origin: .zero,
                                size: titleSize)
    } else {
      let tagViewFittingSize = tagView.systemLayoutSizeFitting(bounds.size)
      let tagViewSize = CGSize(width: min(bounds.width, tagViewFittingSize.width), height: tagViewFittingSize.height)
      
      let titleWidth = bounds.width - tagViewSize.width
      let titleSize = CGSize(width: titleWidth, height: titleFittingSize.height)
      
      titleLabel.frame = CGRect(origin: CGPoint(x: 0, y: 0),
                                size: titleSize)
      
      let tagViewOrigin = CGPoint(x: titleWidth.isZero ? 0 : titleLabel.frame.maxX,
                                  y: bounds.height/2 - tagViewSize.height/2)
      tagView.frame = CGRect(origin: tagViewOrigin,
                             size: tagViewSize)
    }
  }
  
  public override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
    let titleFittingSize = titleLabel.systemLayoutSizeFitting(targetSize)
    if tagView.isHidden {
      return titleFittingSize
    } else {
      let tagViewFittingSize = tagView.systemLayoutSizeFitting(targetSize)
      let resultWidth = titleFittingSize.width + .tagSpacing + tagViewFittingSize.width
      let resultHeight = titleFittingSize.height
      return CGSize(width: resultWidth, height: resultHeight)
    }
  }
    
  public struct Model {
    public let title: NSAttributedString
    public let tagViewModel: TKTagView.Model?
    
    public init(title: NSAttributedString,
                tagViewModel: TKTagView.Model? = nil) {
      self.title = title
      self.tagViewModel = tagViewModel
    }
    
    public init(title: String,
                tagViewModel: TKTagView.Model? = nil) {
      self.title = title.withTextStyle(.label1, color: .Text.primary, alignment: .left, lineBreakMode: .byTruncatingTail)
      self.tagViewModel = tagViewModel
    }
  }
  
  public func configure(model: Model) {
    titleLabel.attributedText = model.title
    if let tagViewModel = model.tagViewModel {
      tagView.isHidden = false
      tagView.configure(model: tagViewModel)
    } else {
      tagView.isHidden = true
    }
    setNeedsLayout()
  }
}

private extension TKTextWithTagView {
  func setup() {
    titleLabel.contentMode = .redraw
    addSubview(titleLabel)
    addSubview(tagView)
  }
}

private extension CGFloat {
  static let tagSpacing: CGFloat = 6
}

