import UIKit
import TKUIKit
import TKQRCode

final class KeyDetailsQRCodeCell: UICollectionViewCell, ReusableView, ConfigurableView {

  var padding: NSDirectionalEdgeInsets = .zero

  private let qrCodeImageView = TKQRCodeImageView(frame: .zero)

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
    let qrCode: QRCode?
  }

  func configure(model: Model) {
    qrCodeImageView.setQRCode(model.qrCode)
    setNeedsLayout()
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    qrCodeImageView.setQRCode(nil)
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
    qrCodeImageView.contentMode = .scaleAspectFit

    contentView.addSubview(qrCodeImageView)
    setupConstraints()
  }

  func setupConstraints() {
    qrCodeImageView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      qrCodeImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
      qrCodeImageView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 24),
      qrCodeImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
      qrCodeImageView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -24)
    ])
  }
}
