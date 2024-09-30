import UIKit
import TKUIKit

final class CollectibleCollectionViewCell: UICollectionViewCell, ConfigurableView, ReusableView {
  private let highlightView = TKHighlightView()
  private let imageView = UIImageView()
  private let labelContainer = UIView()
  private let saleImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.image = .TKUIKit.Icons.Size16.saleBadge
    imageView.tintColor = .white
    imageView.isHidden = true
    return imageView
  }()
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()
  private let blurView = TKSecureBlurView()
  
  private var imageDownloadTask: ImageDownloadTask?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  class Model: Hashable {
    enum Subtitle {
      case verified(String)
      case unverified(String)
    }
    
    let identifier: String
    let imageDownloadTask: ImageDownloadTask?
    let title: NSAttributedString?
    let subtitle: NSAttributedString?
    let isOnSale: Bool
    let isBlurVisible: Bool
    
    init(identifier: String,
         imageDownloadTask: ImageDownloadTask?,
         title: String?,
         subtitle: NSAttributedString?,
         isOnSale: Bool = false,
         isBlurVisible: Bool) {
      self.identifier = identifier
      self.imageDownloadTask = imageDownloadTask
      self.title = title?.withTextStyle(
        .label2,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      self.subtitle = subtitle
      self.isOnSale = isOnSale
      self.isBlurVisible = isBlurVisible
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
    blurView.isHidden = !model.isBlurVisible
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
    
    contentView.backgroundColor = .Background.contentTint
    
    titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    
    labelContainer.addSubview(titleLabel)
    labelContainer.addSubview(subtitleLabel)
    contentView.addSubview(highlightView)
    contentView.addSubview(labelContainer)
    contentView.addSubview(imageView)
    contentView.addSubview(blurView)
    contentView.addSubview(saleImageView)
    
    highlightView.snp.makeConstraints { make in
      make.edges.equalTo(contentView)
    }
    
    imageView.snp.makeConstraints { make in
      make.top.left.right.equalTo(contentView)
      make.height.equalTo(imageView.snp.width)
    }
    
    blurView.snp.makeConstraints { make in
      make.edges.equalTo(imageView)
    }
    
    labelContainer.snp.makeConstraints { make in
      make.top.equalTo(imageView.snp.bottom).offset(UIEdgeInsets.labelContainerInsets.top)
      make.left.right.bottom.equalTo(contentView).inset(UIEdgeInsets.labelContainerInsets)
    }
    
    titleLabel.snp.makeConstraints { make in
      make.top.left.right.equalTo(labelContainer)
    }
    
    subtitleLabel.snp.makeConstraints { make in
      make.top.equalTo(titleLabel.snp.bottom)
      make.left.bottom.right.equalTo(labelContainer)
    }
  }
}

private extension UIEdgeInsets {
  static let labelContainerInsets: UIEdgeInsets = .init(top: 8, left: 12, bottom: 8, right: 12)
}

private extension CGFloat {
  static let saleIconSide: CGFloat = 13
  static let saleIconSpace: CGFloat = 10
}
