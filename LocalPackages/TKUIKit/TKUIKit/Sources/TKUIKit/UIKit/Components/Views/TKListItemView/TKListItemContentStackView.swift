import UIKit

public final class TKListItemContentStackView: UIView, ReusableView {
  let titleSubtitleView = TKListItemTitleSubtitleView()
  let descriptionLabel = UILabel()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public  init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let titleSubtitleSize = titleSubtitleView.sizeThatFits(size)
    let descriptionSize = descriptionLabel.tkSizeThatFits(size.width)
    
    let width = [titleSubtitleSize.width, descriptionSize.width].max() ?? 0
    let height = titleSubtitleSize.height + descriptionSize.height
    
    return CGSize(
      width: width,
      height: height
    )
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let descriptionSize = descriptionLabel.tkSizeThatFits(bounds.width)
    let descriptionOrigin = CGPoint(x: 0, y: bounds.height - descriptionSize.height)
    let descriptionFrame = CGRect(origin: descriptionOrigin, size: descriptionSize)
    
    let titleSubtitleSize = CGSize(width: bounds.width, height: bounds.height - descriptionSize.height)
    let titleSubtitleOrigin = CGPoint.zero
    let titleSubtitleFrame = CGRect(origin: titleSubtitleOrigin, size: titleSubtitleSize)
    
    titleSubtitleView.frame = titleSubtitleFrame
    descriptionLabel.frame = descriptionFrame
  }
   
  public func configure(model: Model) {
    titleSubtitleView.configure(model: model.titleSubtitleModel)
    descriptionLabel.attributedText = model.description
    setNeedsLayout()
  }
  
  public struct Model {
    public let titleSubtitleModel: TKListItemTitleSubtitleView.Model
    public let description: NSAttributedString?
    
    public init(titleSubtitleModel: TKListItemTitleSubtitleView.Model, 
                description: NSAttributedString?) {
      self.titleSubtitleModel = titleSubtitleModel
      self.description = description
    }
  }
  
  public func prepareForReuse() {
    titleSubtitleView.prepareForReuse()
    descriptionLabel.attributedText = nil
  }
}

private extension TKListItemContentStackView {
  func setup() {
    descriptionLabel.numberOfLines = 0
    
    addSubview(titleSubtitleView)
    addSubview(descriptionLabel)
  }
}
