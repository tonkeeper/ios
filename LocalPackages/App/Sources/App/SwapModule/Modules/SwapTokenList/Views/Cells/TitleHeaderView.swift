import UIKit
import TKUIKit

open class TitleHeaderCollectionView: UICollectionReusableView, ReusableView, TKCollectionViewSupplementaryContainerViewContentView {
  
  public let titleLabel = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  open override func sizeThatFits(_ size: CGSize) -> CGSize {
    return systemLayoutSizeFitting(
      size,
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .defaultLow
    )
  }
  
  public struct Model {
    public let title: NSAttributedString
  }
  
  public func configure(model: Model) {
    titleLabel.attributedText = model.title
  }
}

private extension TitleHeaderCollectionView {
  func setup() {
    addSubview(titleLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    titleLabel.snp.makeConstraints { make in
      make.left.equalTo(self)
      make.centerY.equalTo(self)
    }
  }
}

