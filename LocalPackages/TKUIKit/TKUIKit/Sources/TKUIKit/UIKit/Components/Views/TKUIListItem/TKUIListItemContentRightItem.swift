import UIKit

public final class TKUIListItemContentRightItem: UIView, TKConfigurableView {
  
  let valueLabel = UILabel()
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
    let valueSizeThatFits = valueLabel.sizeThatFits(size)
    let valueSize = CGSize(
      width: min(valueSizeThatFits.width, size.width),
      height: valueSizeThatFits.height
    )
    
    let subtitleSizeThatFits = subtitleLabel.sizeThatFits(size)
    let subtitleSize = CGSize(
      width: min(subtitleSizeThatFits.width, size.width),
      height: subtitleSizeThatFits.height
    )
    
    let descriptionSizeThatFits = descriptionLabel.sizeThatFits(size)
    
    let width = [valueSize.width, subtitleSize.width, descriptionSizeThatFits.width].max() ?? 0
    let height = valueSize.height + subtitleSize.height + descriptionSizeThatFits.height

    return CGSize(width: width, height: height)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let valueSizeThatFits = valueLabel.sizeThatFits(bounds.size)
    let valueSize = CGSize(
      width: min(valueSizeThatFits.width, bounds.width),
      height: valueSizeThatFits.height
    )

    let valueFrame = CGRect(origin: CGPoint(x: bounds.width - valueSize.width, y: 0), size: valueSize)

    let subtitleSizeThatFits = subtitleLabel.sizeThatFits(bounds.size)
    let subtitleSize = CGSize(
      width: min(subtitleSizeThatFits.width, bounds.width),
      height: subtitleSizeThatFits.height
    )
    let subtitleFrame = CGRect(origin: CGPoint(x: bounds.width - subtitleSize.width, y: valueFrame.maxY), size: subtitleSize)
    
    let descriptionSizeThatFits = descriptionLabel.sizeThatFits(bounds.size)
    let descriptionFrame = CGRect(origin: CGPoint(x: bounds.width - descriptionSizeThatFits.width, y: subtitleFrame.maxY), size: descriptionSizeThatFits)
    
    valueLabel.frame = valueFrame
    subtitleLabel.frame = subtitleFrame
    descriptionLabel.frame = descriptionFrame
  }
  
  public struct Configuration: Hashable {
    public let value: NSAttributedString?
    public let valueNumberOfLines: Int
    public let subtitle: NSAttributedString?
    public let description: NSAttributedString?
    public let descriptionNumberOfLines: Int

    public init(value: NSAttributedString?,
                valueNumberOfLines: Int = 1,
                subtitle: NSAttributedString?,
                description: NSAttributedString?,
                descriptionNumberOfLines: Int = 0) {
      self.value = value
      self.valueNumberOfLines = valueNumberOfLines
      self.subtitle = subtitle
      self.description = description
      self.descriptionNumberOfLines = descriptionNumberOfLines
    }
  }
  
  public func configure(configuration: Configuration) {
    valueLabel.attributedText = configuration.value
    valueLabel.numberOfLines = configuration.valueNumberOfLines
    subtitleLabel.attributedText = configuration.subtitle
    descriptionLabel.attributedText = configuration.description
    descriptionLabel.numberOfLines = configuration.descriptionNumberOfLines
    setNeedsLayout()
  }
}

private extension TKUIListItemContentRightItem {
  func setup() {
    addSubview(valueLabel)
    addSubview(subtitleLabel)
    addSubview(descriptionLabel)
  }
}
