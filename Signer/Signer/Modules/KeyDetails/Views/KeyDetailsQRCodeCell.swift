import UIKit
import TKUIKit

final class KeyDetailsQRCodeCell: UICollectionViewCell, ReusableView, ConfigurableView {

  var padding: NSDirectionalEdgeInsets = .zero

  private let imageView = UIImageView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return CGSize(width: size.width, height: size.width)
  }
  
  override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
    guard let modifiedAttributes = layoutAttributes.copy() as? UICollectionViewLayoutAttributes else {
      return layoutAttributes
    }
    modifiedAttributes.frame.size.height = modifiedAttributes.frame.size.width
    
    return modifiedAttributes
  }

  // MARK: - ConfigurableView

  struct Model: Hashable {
    let image: UIImage?
  }

  func configure(model: Model) {
    imageView.image = model.image
    setNeedsLayout()
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    imageView.image = nil
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    let path = UIBezierPath(
      roundedRect: bounds,
      byRoundingCorners: [
        .bottomLeft,
        .bottomRight
      ],
      cornerRadii: CGSize(width: 16, height: 16)
    )
    let mask = CAShapeLayer()
    mask.path = path.cgPath
    layer.mask = mask
  }
}

private extension KeyDetailsQRCodeCell {
  func setup() {
    backgroundColor = .white

    contentView.addSubview(imageView)
    setupConstraints()
  }

  func setupConstraints() {
    imageView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
      imageView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 24),
      imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
      imageView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -24)
    ])
  }
}
