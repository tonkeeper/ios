import UIKit
import TKUIKit

final class SuggestedTokenCell: TKCollectionViewNewCell, TKConfigurableView {
  
  private let tokenButtonContentView = SwapTokenButtonContentView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    tokenButtonContentView.prepareForReuse()
  }
  
  public override func preferredLayoutAttributesFitting(
    _ layoutAttributes: UICollectionViewLayoutAttributes
  ) -> UICollectionViewLayoutAttributes {
    guard let modifiedAttributes = layoutAttributes.copy() as? UICollectionViewLayoutAttributes else {
      return layoutAttributes
    }
    
    let resultSize = tokenButtonContentView.sizeThatFits(bounds.size)
    modifiedAttributes.frame.size = resultSize
    
    return modifiedAttributes
  }
  
  public struct Configuration: Hashable {
    public let id: String
    public let tokenButtonModel: SwapTokenButtonContentView.Model
    public let selectionClosure: (() -> Void)?
    
    init(id: String,
         tokenButtonModel: SwapTokenButtonContentView.Model,
         selectionClosure: (() -> Void)?) {
      self.id = id
      self.tokenButtonModel = tokenButtonModel
      self.selectionClosure = selectionClosure
    }
    
    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }
    
    public static func ==(lhs: Configuration, rhs: Configuration) -> Bool {
      lhs.id == rhs.id
    }
  }
  
  public func configure(configuration: Configuration) {
    tokenButtonContentView.configure(model: configuration.tokenButtonModel)
    setNeedsLayout()
  }
}

private extension SuggestedTokenCell {
  func setup() {
    layer.masksToBounds = true
    
    backgroundColor = .Button.secondaryBackground
    hightlightColor = .Button.secondaryBackgroundHighlighted
    contentViewPadding = .zero
    
    contentContainerView.addSubview(tokenButtonContentView)
  }
}
