import UIKit

public final class TKListItemTitleView: UIView {
  
  public struct Configuration {
    public struct Icon {
      public var image: UIImage
      public var tintColor: UIColor?
      
      public init(image: UIImage,
                  tintColor: UIColor? = nil) {
        self.image = image
        self.tintColor = tintColor
      }
    }
    
    public var title: NSAttributedString
    public var caption: NSAttributedString?
    public var tagConfiguration: TKTagView.Configuration?
    public var icon: Icon?
    
    public init(title: String,
                caption: String? = nil,
                tagConfiguration: TKTagView.Configuration? = nil,
                icon: Icon? = nil) {
      self.title = title.withTextStyle(
        .label1,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      self.caption = caption?.withTextStyle(
        .label1,
        color: .Text.tertiary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      self.tagConfiguration = tagConfiguration
      self.icon = icon
    }
  }
  
  public var configuration = Configuration(title: "") {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  let titleLabel = UILabel()
  let captionLabel = UILabel()
  let tagView = TKTagView()
  let iconImageView = UIImageView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let layoutSize = calculateLayoutSize(size: bounds.size)
    
    let titleFrame = CGRect(origin: CGPoint(x: 0, y: bounds.height/2 - layoutSize.titleSize.height/2),
                            size: layoutSize.titleSize)
    let captionFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + .captionPadding, y: bounds.height/2 - layoutSize.captionSize.height/2),
                              size: layoutSize.captionSize)
    let tagFrame = CGRect(origin: CGPoint(x: captionFrame.maxX, y: bounds.height/2 - layoutSize.tagSize.height/2),
                          size: layoutSize.tagSize)
    let iconFrame = CGRect(origin: CGPoint(x: tagFrame.maxX + .iconLeftPadding, y: bounds.height/2 - layoutSize.iconSize.height/2),
                           size: layoutSize.iconSize)
    titleLabel.frame = titleFrame
    captionLabel.frame = captionFrame
    tagView.frame = tagFrame
    iconImageView.frame = iconFrame
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let layoutSize = calculateLayoutSize(size: size)
    let width = layoutSize.titleSize.width
    + layoutSize.captionSize.width
    + .captionPadding
    + layoutSize.tagSize.width
    + .iconLeftPadding
    + layoutSize.iconSize.width
    let height = layoutSize.maximumHeight
    return CGSize(width: width, height: height)
  }
  
  public override var intrinsicContentSize: CGSize {
    sizeThatFits(CGSize(width: CGFloat.infinity, height: 0))
  }
  
  private func setup() {
    addSubview(titleLabel)
    addSubview(captionLabel)
    addSubview(tagView)
    addSubview(iconImageView)
    
    didUpdateConfiguration()
  }
  
  private func didUpdateConfiguration() {
    titleLabel.attributedText = configuration.title
    captionLabel.attributedText = configuration.caption
    if let tagConfiguration = configuration.tagConfiguration {
      tagView.configuration = tagConfiguration
      tagView.isHidden = false
    } else {
      tagView.isHidden = true
    }
    if let icon = configuration.icon {
      iconImageView.image = icon.image
      iconImageView.tintColor = icon.tintColor
      iconImageView.isHidden = false
    } else {
      iconImageView.image = nil
      iconImageView.tintColor = nil
      iconImageView.isHidden = true
    }
  }
  
  private struct LayoutSize {
    let titleSize: CGSize
    let captionSize: CGSize
    let tagSize: CGSize
    let iconSize: CGSize
    
    var maximumHeight: CGFloat {
      [iconSize, tagSize, titleSize, captionSize].max { $0.height < $1.height }?.height ?? .zero
    }
  }
  
  private func calculateLayoutSize(size: CGSize) -> LayoutSize {
    let iconSize: CGSize = {
      if iconImageView.isHidden {
        return .zero
      } else {
        let sizeThatFits = iconImageView.sizeThatFits(size)
        return CGSize(width: sizeThatFits.width, height: sizeThatFits.height)
      }
    }()
    
    let tagSize: CGSize = {
      if tagView.isHidden {
        return .zero
      } else {
        let sizeThatFits = tagView.sizeThatFits(CGSize(width: size.width - iconSize.width - .iconLeftPadding, height: 0))
        return sizeThatFits
      }
    }()
    
    let titleSize: CGSize = {
      let width = size.width - iconSize.width - .iconLeftPadding - tagSize.width
      let sizeThatFits = titleLabel.sizeThatFits(CGSize(width: width,
                                                        height: 0))
      let resultWidth = min(width, sizeThatFits.width)
      return CGSize(width: resultWidth, height: sizeThatFits.height)
    }()
    
    let captionSize: CGSize = {
      if captionLabel.isHidden {
        return .zero
      } else {
        let width = size.width - iconSize.width - tagSize.width - titleSize.width - .iconLeftPadding - .captionPadding
        let sizeThatFits = captionLabel.sizeThatFits(CGSize(width: width, height: 0))
        let resultWidth = min(width, sizeThatFits.width)
        return CGSize(width: resultWidth, height: sizeThatFits.height)
      }
    }()
    
    return LayoutSize(
      titleSize: titleSize,
      captionSize: captionSize,
      tagSize: tagSize,
      iconSize: iconSize
    )
  }
}

private extension CGFloat {
  static let iconLeftPadding: CGFloat = 6
  static let captionPadding: CGFloat = 4
}
