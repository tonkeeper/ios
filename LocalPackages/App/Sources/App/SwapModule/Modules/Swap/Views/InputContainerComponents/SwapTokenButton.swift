import UIKit
import TKUIKit

// MARK: - SwapTokenButton

final class SwapTokenButton: TKUIButton<SwapTokenButtonContentView, TKUIButtonDefaultBackgroundView> {
  
  init() {
    super.init(
      contentView: SwapTokenButtonContentView(),
      backgroundView: TKUIButtonDefaultBackgroundView(cornerRadius: 18),
      contentHorizontalPadding: 0
    )
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func setupButtonState() {
    switch buttonState {
    case .normal:
      backgroundView.setBackgroundColor(.Button.tertiaryBackground)
    case .highlighted:
      backgroundView.setBackgroundColor(.Button.tertiaryBackgroundHighlighted)
    case .disabled:
      backgroundView.setBackgroundColor(.Button.tertiaryBackground.withAlphaComponent(0.48))
    case .selected:
      backgroundView.setBackgroundColor(.Button.tertiaryBackground)
    }
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return contentView.sizeThatFits(size)
  }
  
  private func setup () {
    backgroundView.backgroundColor = .Button.tertiaryBackground
  }
}

// MARK: - ContentView

final class SwapTokenButtonContentView: UIView, ConfigurableView {
  
  private var hasIcon: Bool {
    !iconImageView.isHidden
  }
  
  private var contentPadding: UIEdgeInsets {
    let leftPadding: CGFloat = hasIcon ? 4 : 14
    return UIEdgeInsets(top: 4, left: leftPadding, bottom: 4, right: 14)
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
  
  private var imageDownloadTask: ImageDownloadTask?
  
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
    
    let titleLabelX = hasIcon ? contentPadding.left + CGSize.iconSize.width + .spacing : contentPadding.left
    let titleLabelOrigin = CGPoint(x: titleLabelX, y: contentPadding.top)
    var titleLabelSize = titleLabel.sizeThatFits(bounds.size)
    titleLabelSize.height = CGSize.iconSize.height
    
    iconImageView.frame = CGRect(origin: iconImageViewOrigin, size: .iconSize)
    titleLabel.frame = CGRect(origin: titleLabelOrigin, size: titleLabelSize)
    
    iconImageView.layer.cornerRadius = iconImageView.bounds.height/2
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let contentPadding = self.contentPadding
    
    let iconImageWidth: CGFloat = hasIcon ? CGSize.iconSize.width : 0
    let spacing: CGFloat = hasIcon ? .spacing : 0
    let titleWidth = titleLabel.sizeThatFits(bounds.size).width
    
    let width = iconImageWidth + spacing + titleWidth + contentPadding.left + contentPadding.right
    let height = CGSize.iconSize.height + contentPadding.top + contentPadding.bottom
    
    return CGSize(width: width, height: height)
  }
  
  struct Model {
    enum Icon {
      case image(UIImage?)
      case asyncImage(ImageDownloadTask)
    }
    
    let title: NSAttributedString
    let icon: Icon
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title
    
    imageDownloadTask?.cancel()
    
    switch model.icon {
    case .image(let image):
      iconImageView.image = image
      iconImageView.isHidden = image == nil
    case .asyncImage(let imageDownloadTask):
      let size = CGSize.iconSize
      imageDownloadTask.start(imageView: iconImageView, size: size, cornerRadius: size.width/2)
      self.imageDownloadTask = imageDownloadTask
    }
    
    iconImageView.backgroundColor = .Background.contentTint
    
    setNeedsLayout()
  }
  
  private func setup() {
    iconImageView.backgroundColor = .Background.contentTint
    
    addSubview(iconImageView)
    addSubview(titleLabel)
  }
}

extension SwapTokenButtonContentView: ReusableView {
  func prepareForReuse() {
    imageDownloadTask?.cancel()
    imageDownloadTask = nil
    iconImageView.image = nil
  }
}

private extension CGFloat {
  static let spacing: CGFloat = 6
}

private extension CGSize {
  static let iconSize: CGSize = CGSize(width: 28, height: 28)
}
