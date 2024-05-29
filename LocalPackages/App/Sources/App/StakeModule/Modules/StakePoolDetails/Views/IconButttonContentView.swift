import UIKit
import TKUIKit
import TKCore

final class IconButttonContentView: UIView, ConfigurableView {
  
  struct Paddings {
    var contentPaddingWithIcon = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 14)
    var contentPaddingWithoutIcon = UIEdgeInsets(top: 4, left: 14, bottom: 4, right: 14)
  }
  
  private var hasIcon: Bool {
    !iconImageView.isHidden
  }
  
  private var contentPadding: UIEdgeInsets {
    return hasIcon ? padddings.contentPaddingWithIcon : padddings.contentPaddingWithoutIcon
  }
  
  var padddings: Paddings = Paddings() {
    didSet {
      setNeedsLayout()
    }
  }
  
  let iconImageView = UIImageView()
  let titleLabel = UILabel()
  let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.alignment = .center
    stackView.distribution = .equalSpacing
    return stackView
  }()
  
  private var imageDownloadTask: TKCore.ImageDownloadTask?
  private var iconImageSize = CGSize(width: 28, height: 28)
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let contentPadding = self.contentPadding
    
    let iconImageViewOrigin = CGPoint(x: contentPadding.left, y: contentPadding.top)
    
    let titleLabelX = hasIcon ? contentPadding.left + iconImageSize.width + .spacing : contentPadding.left
    let titleLabelOrigin = CGPoint(x: titleLabelX, y: contentPadding.top)
    var titleLabelSize = titleLabel.sizeThatFits(bounds.size)
    titleLabelSize.height = iconImageSize.height
    
    iconImageView.frame = CGRect(origin: iconImageViewOrigin, size: iconImageSize)
    titleLabel.frame = CGRect(origin: titleLabelOrigin, size: titleLabelSize)
    
    iconImageView.layer.cornerRadius = iconImageView.bounds.height/2
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let contentPadding = self.contentPadding
    
    let iconImageWidth: CGFloat = hasIcon ? iconImageSize.width : 0
    let spacing: CGFloat = hasIcon ? .spacing : 0
    let titleWidth = titleLabel.sizeThatFits(bounds.size).width
    
    let width = iconImageWidth + spacing + titleWidth + contentPadding.left + contentPadding.right
    let height = iconImageSize.height + contentPadding.top + contentPadding.bottom
    
    return CGSize(width: width, height: height)
  }
  
  struct Model {
    enum Icon {
      case image(UIImage?)
      case asyncImage(TKCore.ImageDownloadTask)
    }
    
    let title: NSAttributedString
    let icon: Icon
    let iconTint: UIColor?
    let iconSize: CGSize
    let paddings: Paddings
    
    init(title: NSAttributedString,
         icon: Icon,
         iconTint: UIColor? = nil,
         iconSize: CGSize = CGSize(width: 28, height: 28),
         paddings: Paddings = Paddings()) {
      self.title = title
      self.icon = icon
      self.iconTint = iconTint
      self.iconSize = iconSize
      self.paddings = paddings
    }
  }
  
  func configure(model: Model) {
    iconImageSize = model.iconSize
    padddings = model.paddings
    
    titleLabel.attributedText = model.title
    
    imageDownloadTask?.cancel()
    
    switch model.icon {
    case .image(let image):
      iconImageView.image = image
      iconImageView.isHidden = image == nil
    case .asyncImage(let imageDownloadTask):
      iconImageView.image = nil
      iconImageView.isHidden = false
      imageDownloadTask.start(imageView: iconImageView, size: iconImageSize, cornerRadius: iconImageSize.width/2)
      self.imageDownloadTask = imageDownloadTask
    }
    
    iconImageView.tintColor = model.iconTint
    iconImageView.backgroundColor = .Background.contentTint
    
    setNeedsLayout()
  }
  
  private func setup() {
    iconImageView.backgroundColor = .Background.contentTint
    iconImageView.layer.cornerRadius = iconImageSize.height / 2
    iconImageView.layer.masksToBounds = true
    
    addSubview(iconImageView)
    addSubview(titleLabel)
  }
}

extension IconButttonContentView: ReusableView {
  func prepareForReuse() {
    imageDownloadTask?.cancel()
    imageDownloadTask = nil
    iconImageView.image = nil
  }
}

private extension CGFloat {
  static let spacing: CGFloat = 6
}
