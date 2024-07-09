import UIKit

public protocol TKCollectionViewSupplementaryContainerViewContentView: ConfigurableView {
  func prepareForReuse()
}

public class TKCollectionViewSupplementaryContainerView<ContentView: TKCollectionViewSupplementaryContainerViewContentView>: UICollectionReusableView, ConfigurableView, ReusableView {

  public let contentView = ContentView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public func configure(model: ContentView.Model) {
    contentView.configure(model: model)
  }
  
  public override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
    let targetSize = CGSize(width: layoutAttributes.frame.width, height: 0)
    let cellContentViewSize = contentView.sizeThatFits(.init(width: targetSize.width, height: 0))
    let modifiedAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
    modifiedAttributes.frame.size = cellContentViewSize
    return modifiedAttributes
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    contentView.frame = bounds
  }
  
  public override func prepareForReuse() {
    super.prepareForReuse()
    contentView.prepareForReuse()
  }
}

private extension TKCollectionViewSupplementaryContainerView {
  func setup() {
//    backgroundColor = .Background.page
    addSubview(contentView)
  }
}
