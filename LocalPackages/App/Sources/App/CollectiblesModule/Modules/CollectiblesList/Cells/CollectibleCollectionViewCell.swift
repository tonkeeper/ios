import UIKit
import TKUIKit

final class CollectibleCollectionViewCell: UICollectionViewCell, ConfigurableView, ReusableView {
  private let highlightView = TKHighlightView()
  private let imageView = UIImageView()
  private let labelContainer = UIView()
  private let saleImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.image = .Icons.Collectible.sale
    imageView.tintColor = .white
    imageView.isHidden = true
    return imageView
  }()
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()
  
  private var imageDownloadTask: ImageDownloadTask?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  class Model: Hashable {
    let identifier: String
    let imageDownloadTask: ImageDownloadTask?
    let title: NSAttributedString?
    let subtitle: NSAttributedString?
    let isOnSale: Bool
    
    init(identifier: String,
         imageDownloadTask: ImageDownloadTask?,
         title: String?,
         subtitle: String?,
         isOnSale: Bool = false) {
      self.identifier = identifier
      self.imageDownloadTask = imageDownloadTask
      self.title = title?.withTextStyle(
        .label2,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      self.subtitle = subtitle?.withTextStyle(
        .body3,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      self.isOnSale = isOnSale
    }
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(identifier)
    }
    
    static func ==(lhs: Model, rhs: Model) -> Bool {
      return lhs.identifier == rhs.identifier
    }
  }
  
  func configure(model: Model) {
    imageDownloadTask = model.imageDownloadTask
    imageDownloadTask?.start(imageView: imageView, size: nil, cornerRadius: nil)
    titleLabel.attributedText = model.title
    subtitleLabel.attributedText = model.subtitle
    saleImageView.isHidden = !model.isOnSale
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let saleIconFrame = CGRect(x: bounds.width - .saleIconSide - .saleIconSpace,
                               y: .saleIconSpace,
                               width: .saleIconSide, height: .saleIconSide)
    saleImageView.frame = saleIconFrame
  }
  
  override func updateConfiguration(using state: UICellConfigurationState) {
    highlightView.isHighlighted = state.isHighlighted
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    imageView.image = nil
    imageDownloadTask?.cancel()
    imageDownloadTask = nil
  }
}

private extension CollectibleCollectionViewCell {
  func setup() {
    contentView.layer.cornerRadius = 16
    contentView.layer.masksToBounds = true
    
    contentView.backgroundColor = .Background.content
    
    titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    
    labelContainer.addSubview(titleLabel)
    labelContainer.addSubview(subtitleLabel)
    contentView.addSubview(highlightView)
    contentView.addSubview(labelContainer)
    contentView.addSubview(imageView)
    contentView.addSubview(saleImageView)
    
    labelContainer.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
    imageView.translatesAutoresizingMaskIntoConstraints = false
    highlightView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      highlightView.topAnchor.constraint(equalTo: contentView.topAnchor),
      highlightView.leftAnchor.constraint(equalTo: contentView.leftAnchor),
      highlightView.rightAnchor.constraint(equalTo: contentView.rightAnchor),
      highlightView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      
      imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
      imageView.leftAnchor.constraint(equalTo: contentView.leftAnchor),
      imageView.rightAnchor.constraint(equalTo: contentView.rightAnchor)
        .withPriority(.defaultHigh),
      imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
      
      labelContainer.topAnchor.constraint(equalTo: imageView.bottomAnchor),
      labelContainer.leftAnchor.constraint(equalTo: contentView.leftAnchor),
      labelContainer.rightAnchor.constraint(equalTo: contentView.rightAnchor),
      labelContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        .withPriority(.defaultHigh),
      
      titleLabel.topAnchor.constraint(equalTo: labelContainer.topAnchor,
                                      constant: UIEdgeInsets.labelContainerInsets.top),
      titleLabel.leftAnchor.constraint(equalTo: labelContainer.leftAnchor,
                                       constant: UIEdgeInsets.labelContainerInsets.left),
      titleLabel.rightAnchor.constraint(equalTo: labelContainer.rightAnchor,
                                        constant: -UIEdgeInsets.labelContainerInsets.right)
      .withPriority(.defaultHigh),
      
      subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor),
      subtitleLabel.bottomAnchor.constraint(equalTo: labelContainer.bottomAnchor,
                                            constant: -UIEdgeInsets.labelContainerInsets.bottom),
      subtitleLabel.leftAnchor.constraint(equalTo: labelContainer.leftAnchor,
                                          constant: UIEdgeInsets.labelContainerInsets.left),
      subtitleLabel.rightAnchor.constraint(equalTo: labelContainer.rightAnchor, constant:
                                            -UIEdgeInsets.labelContainerInsets.right).withPriority(.defaultHigh),
    ])
  }
}

private extension UIEdgeInsets {
  static let labelContainerInsets: UIEdgeInsets = .init(top: 8, left: 12, bottom: 8, right: 12)
}

private extension CGFloat {
  static let saleIconSide: CGFloat = 13
  static let saleIconSpace: CGFloat = 10
}
