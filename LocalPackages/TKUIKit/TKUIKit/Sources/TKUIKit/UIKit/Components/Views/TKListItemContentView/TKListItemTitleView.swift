import UIKit

public final class TKListItemTitleView: UIView {
  
  public struct Configuration: Hashable {
    public struct Icon: Hashable {
      public var image: UIImage
      public var tintColor: UIColor?
      
      public init(image: UIImage,
                  tintColor: UIColor? = nil) {
        self.image = image
        self.tintColor = tintColor
      }
    }
    
    public struct Title: Hashable {
      public let text: NSAttributedString?
      public let numberOfLines: Int
      
      public init(text: NSAttributedString?, 
                  numberOfLines: Int) {
        self.text = text
        self.numberOfLines = numberOfLines
      }
    }
    
    public var title: Title
    public var caption: NSAttributedString?
    public var tags: [TKTagView.Configuration]
    public var icon: Icon?
    
    public init(title: String,
                caption: String? = nil,
                tags: [TKTagView.Configuration] = [],
                icon: Icon? = nil) {
      self.title = Title(text: title.withTextStyle(
        .label1,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      ), numberOfLines: 1)
      self.caption = caption?.withTextStyle(
        .label1,
        color: .Text.tertiary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      self.tags = tags
      self.icon = icon
    }
    
    public init(title: NSAttributedString?, numberOfLines: Int) {
      self.title = Title(text: title, numberOfLines: numberOfLines)
      self.caption = nil
      self.tags = []
      self.icon = nil
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
  let iconImageView = UIImageView()
  var tagViews = [TKTagView]()
  
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
    
    var tagOriginX = captionFrame.maxX
    tagViews.enumerated().forEach { index, view in
      guard layoutSize.tagSizes.count > index else { return }
      let size = layoutSize.tagSizes[index]
      let frame = CGRect(origin: CGPoint(x: tagOriginX, y: bounds.height/2 - size.height/2),
                         size: size)
      view.frame = frame
      tagOriginX = view.frame.maxX
    }

    let iconFrame = CGRect(origin: CGPoint(x: tagOriginX + .iconLeftPadding, y: bounds.height/2 - layoutSize.iconSize.height/2),
                           size: layoutSize.iconSize)
    titleLabel.frame = titleFrame
    captionLabel.frame = captionFrame
    iconImageView.frame = iconFrame
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let layoutSize = calculateLayoutSize(size: size)
    let width = layoutSize.titleSize.width
    + layoutSize.captionSize.width
    + .captionPadding
    + layoutSize.tagSizes.map { $0.width }.reduce(0, +)
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
    addSubview(iconImageView)
    
    didUpdateConfiguration()
  }
  
  private func didUpdateConfiguration() {
    titleLabel.attributedText = configuration.title.text
    titleLabel.numberOfLines = configuration.title.numberOfLines
    captionLabel.attributedText = configuration.caption
    
    tagViews.forEach { $0.removeFromSuperview() }
    tagViews.removeAll()
    configuration.tags.forEach {
      let view = TKTagView()
      view.configuration = $0
      addSubview(view)
      tagViews.append(view)
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
    let tagSizes: [CGSize]
    let iconSize: CGSize
    
    var maximumHeight: CGFloat {
      [iconSize.height, tagSizes.map { $0.height }.max() ?? 0, titleSize.height, captionSize.height].max() ?? .zero
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
    
    var tagSizes = [CGSize]()
    var tagSizeCalculationWidth = size.width - iconSize.width - .iconLeftPadding
    for tagView in tagViews {
      let sizeThatFits = tagView.sizeThatFits(CGSize(width: tagSizeCalculationWidth, height: 0))
      tagSizes.append(sizeThatFits)
      tagSizeCalculationWidth -= sizeThatFits.width
    }
    let tagsWidth = tagSizes.map { $0.width }.reduce(0, +)

    let titleSize: CGSize = {
      let width = size.width - iconSize.width - .iconLeftPadding - tagsWidth
      let sizeThatFits = titleLabel.sizeThatFits(CGSize(width: width,
                                                        height: 0))
      let resultWidth = min(width, sizeThatFits.width)
      return CGSize(width: resultWidth, height: sizeThatFits.height)
    }()
    
    let captionSize: CGSize = {
      if captionLabel.isHidden {
        return .zero
      } else {
        let width = size.width - iconSize.width - tagsWidth - titleSize.width - .iconLeftPadding - .captionPadding
        let sizeThatFits = captionLabel.sizeThatFits(CGSize(width: width, height: 0))
        let resultWidth = min(width, sizeThatFits.width)
        return CGSize(width: resultWidth, height: sizeThatFits.height)
      }
    }()
    
    return LayoutSize(
      titleSize: titleSize,
      captionSize: captionSize,
      tagSizes: tagSizes,
      iconSize: iconSize
    )
  }
}

private extension CGFloat {
  static let iconLeftPadding: CGFloat = 6
  static let captionPadding: CGFloat = 4
}
