import UIKit

public final class TKListItemContentView: UIView, ReusableView, ConfigurableView {
  let leftContentStackView = TKListItemContentStackView()
  let rightContentStackView = TKListItemContentStackView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public  init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let rightContentStackViewSize = rightContentStackView.sizeThatFits(size)
    
    let leftContentStackViewFitSize = CGSize(width: size.width - rightContentStackViewSize.width, height: size.height)
    let leftContentStackViewSize = leftContentStackView.sizeThatFits(leftContentStackViewFitSize)
    
    let width = size.width
    let height = [rightContentStackViewSize.height, leftContentStackViewSize.height].max() ?? 0
    
    return CGSize(width: width, height: height)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let rightContentSize = rightContentStackView.sizeThatFits(
      bounds.size
    )
    let rightContentOrigin = CGPoint(
      x: bounds.width - rightContentSize.width,
      y: 0
    )
    let rightContentFrame = CGRect(
      origin: rightContentOrigin,
      size: CGSize(
        width: rightContentSize.width,
        height: rightContentSize.height
      )
    )
    
    let leftContentSize = leftContentStackView.sizeThatFits(
      bounds.size
    )
    let leftContentOrigin = CGPoint(
      x: 0,
      y: bounds.height/2 - leftContentSize.height/2
    )
    let leftContentFrame = CGRect(
      origin: leftContentOrigin,
      size: CGSize(
        width: bounds.width - rightContentSize.width,
        height: leftContentSize.height
      )
    )
    
    leftContentStackView.frame = leftContentFrame
    rightContentStackView.frame = rightContentFrame
  }
   
  public func configure(model: Model) {
    leftContentStackView.configure(model: model.leftContentStackViewModel)
    if let rightContentStackViewModel = model.rightContentStackViewModel {
      rightContentStackView.isHidden = false
      rightContentStackView.configure(model: rightContentStackViewModel)
    } else {
      rightContentStackView.isHidden = true
    }
    setNeedsLayout()
  }
  
  public struct Model {
    public let leftContentStackViewModel: TKListItemContentStackView.Model
    public let rightContentStackViewModel: TKListItemContentStackView.Model?
    
    public init(leftContentStackViewModel: TKListItemContentStackView.Model,
                rightContentStackViewModel: TKListItemContentStackView.Model?) {
      self.leftContentStackViewModel = leftContentStackViewModel
      self.rightContentStackViewModel = rightContentStackViewModel
    }
  }
  
  public func prepareForReuse() {
    leftContentStackView.prepareForReuse()
    rightContentStackView.prepareForReuse()
  }
}

private extension TKListItemContentView {
  func setup() {
    addSubview(leftContentStackView)
    addSubview(rightContentStackView)
  }
}
