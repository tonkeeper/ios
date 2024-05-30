import UIKit
import TKUIKit
import SnapKit

open class DescriptionFooterCollectionView: UICollectionReusableView, ReusableView, TKCollectionViewSupplementaryContainerViewContentView {
  
  public let descriptionLabel = UILabel()
  
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
    descriptionLabel.attributedText = model.title
  }
}

private extension DescriptionFooterCollectionView {
  func setup() {
    descriptionLabel.numberOfLines = 0
    
    addSubview(descriptionLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    descriptionLabel.snp.makeConstraints { make in
      make.left.right.equalTo(self)
      make.top.equalTo(self).offset(12)
    }
  }
}
