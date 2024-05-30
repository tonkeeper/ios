import UIKit
import TKUIKit

final class IconButtonCell: TKCollectionViewNewCell, TKConfigurableView {
  
  private let iconButtonContentView = IconButttonContentView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    iconButtonContentView.prepareForReuse()
  }
  
  public override func preferredLayoutAttributesFitting(
    _ layoutAttributes: UICollectionViewLayoutAttributes
  ) -> UICollectionViewLayoutAttributes {
    guard let modifiedAttributes = layoutAttributes.copy() as? UICollectionViewLayoutAttributes else {
      return layoutAttributes
    }
    
    let resultSize = iconButtonContentView.sizeThatFits(bounds.size)
    modifiedAttributes.frame.size = resultSize
    
    return modifiedAttributes
  }
  
  public struct Configuration: Hashable {
    public let id: String
    public let iconButton: IconButttonContentView.Model
    public let selectionClosure: (() -> Void)?
    
    init(id: String,
         iconButton: IconButttonContentView.Model,
         selectionClosure: (() -> Void)?) {
      self.id = id
      self.iconButton = iconButton
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
    iconButtonContentView.configure(model: configuration.iconButton)
    setNeedsLayout()
  }
}

private extension IconButtonCell {
  func setup() {
    layer.masksToBounds = true
    
    backgroundColor = .Button.secondaryBackground
    hightlightColor = .Button.secondaryBackgroundHighlighted
    contentViewPadding = .zero
    
    contentContainerView.addSubview(iconButtonContentView)
  }
}
