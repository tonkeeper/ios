import UIKit

public final class TKUIListItemContentLeftItem: UIView, TKConfigurableView {
  
  let titleLabel = UILabel()
  let tagView = TKUITagView()
  let subtitleLabel = UILabel()
  let descriptionLabel = UILabel()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let tagSizeThatFits = tagView.sizeThatFits(size)
    let tagSize = CGSize(
      width: min(tagSizeThatFits.width, size.width),
      height: tagSizeThatFits.height
    )
    
    let titleSizeThatFits = titleLabel.sizeThatFits(size)
    let titleSize = CGSize(
      width: min(titleSizeThatFits.width, size.width - tagSize.width),
      height: titleSizeThatFits.height
    )
    
    let subtitleSizeThatFits = subtitleLabel.sizeThatFits(size)
    let subtitleSize = CGSize(
      width: min(subtitleSizeThatFits.width, size.width),
      height: subtitleSizeThatFits.height
    )
    
    let descriptionSizeThatFits = descriptionLabel.sizeThatFits(size)
    
    let width = [titleSize.width + tagSize.width, subtitleSize.width, descriptionSizeThatFits.width].max() ?? 0
    let height = titleSize.height + subtitleSize.height + descriptionSizeThatFits.height

    return CGSize(width: width, height: height)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let tagSize: CGSize
    if tagView.isHidden {
      tagSize = .zero
    } else {
      let tagSizeThatFits = tagView.sizeThatFits(bounds.size)
      tagSize = CGSize(
        width: min(tagSizeThatFits.width, bounds.width),
        height: tagSizeThatFits.height
      )
    }
    
    let titleSizeThatFits = titleLabel.sizeThatFits(bounds.size)
    let titleSize = CGSize(
      width: min(titleSizeThatFits.width, bounds.width - tagSize.width),
      height: titleSizeThatFits.height
    )
    let titleFrame = CGRect(origin: CGPoint(x: 0, y: 0), size: titleSize)

    let tagFrame = CGRect(origin: CGPoint(x: titleFrame.maxX, y: titleFrame.midY - tagSize.height/2), size: tagSize)
    
    let subtitleSizeThatFits = subtitleLabel.sizeThatFits(bounds.size)
    let subtitleSize = CGSize(
      width: min(subtitleSizeThatFits.width, bounds.width),
      height: subtitleSizeThatFits.height
    )
    let subtitleFrame = CGRect(origin: CGPoint(x: 0, y: titleFrame.maxY), size: subtitleSize)
    
    let descriptionSizeThatFits = descriptionLabel.sizeThatFits(bounds.size)
    let descriptionFrame = CGRect(origin: CGPoint(x: 0, y: subtitleFrame.maxY), size: descriptionSizeThatFits)
    
    titleLabel.frame = titleFrame
    tagView.frame = tagFrame
    subtitleLabel.frame = subtitleFrame
    descriptionLabel.frame = descriptionFrame
  }
  
  public struct Configuration: Hashable {
    public let title: NSAttributedString?
    public let tagViewModel: TKUITagView.Configuration?
    public let subtitle: NSAttributedString?
    public let description: NSAttributedString?
    public let descriptionNumberOfLines: Int

    public init(title: NSAttributedString?,
                tagViewModel: TKUITagView.Configuration?,
                subtitle: NSAttributedString?,
                description: NSAttributedString?,
                descriptionNumberOfLines: Int = 0) {
      self.title = title
      self.tagViewModel = tagViewModel
      self.subtitle = subtitle
      self.description = description
      self.descriptionNumberOfLines = descriptionNumberOfLines
    }
  }
  
  public func configure(configuration: Configuration) {
    titleLabel.attributedText = configuration.title
    if let tagViewModel = configuration.tagViewModel {
      tagView.configure(configuration: tagViewModel)
      tagView.isHidden = false
    } else {
      tagView.isHidden = true
    }
    
    subtitleLabel.attributedText = configuration.subtitle
    descriptionLabel.attributedText = configuration.description
    descriptionLabel.numberOfLines = configuration.descriptionNumberOfLines
    setNeedsLayout()
  }
}

private extension TKUIListItemContentLeftItem {
  func setup() {
    addSubview(titleLabel)
    addSubview(tagView)
    addSubview(subtitleLabel)
    addSubview(descriptionLabel)
  }
}
