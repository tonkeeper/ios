import UIKit
import SnapKit
import TKCore

final class ServiceInfoContainerView: UIView {
  private let iconImageView = UIImageView()
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()
  
  override var intrinsicContentSize: CGSize { sizeThatFits(bounds.size) }
  
  private var imageDownloadTask: TKCore.ImageDownloadTask?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    iconImageView.layer.masksToBounds = true
    iconImageView.layer.cornerRadius = .iconImageCornerRadius
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let iconImageHeight = CGSize.iconImageSize.height
    let titleHeight = titleLabel.sizeThatFits(size).height
    let subtitleHeight = subtitleLabel.sizeThatFits(size).height
    var height = iconImageHeight
    height += .iconImageBottomPadding
    height += titleHeight
    height += .interLabelPadding
    height += subtitleHeight
    height += .subtitleLabelBottomPadding
    
    return CGSize(width: bounds.width, height: height)
  }
  
  struct Configuration {
    enum Image {
      case image(UIImage?)
      case asyncImage(TKCore.ImageDownloadTask)
    }
    
    let image: Image
    let title: NSAttributedString
    let subtitle: NSAttributedString
  }
  
  func configure(configuration: Configuration) {
    titleLabel.attributedText = configuration.title
    subtitleLabel.attributedText = configuration.subtitle
    setIconImage(configuration.image)
    
    setNeedsDisplay()
  }
  
  private func setIconImage(_ imageConfiguration: Configuration.Image) {
    imageDownloadTask?.cancel()
    imageDownloadTask = nil
    
    switch imageConfiguration {
    case .image(let image):
      iconImageView.image = image
    case .asyncImage(let imageDownloadTask):
      self.imageDownloadTask = imageDownloadTask
      imageDownloadTask.start(
        imageView: iconImageView,
        size: .iconImageSize,
        cornerRadius: 0
      )
    }
  }
}

// MARK: - Setup

private extension ServiceInfoContainerView {
  func setup() {
    iconImageView.backgroundColor = .Background.contentTint
    
    addSubview(iconImageView)
    addSubview(titleLabel)
    addSubview(subtitleLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    iconImageView.snp.makeConstraints { make in
      make.size.equalTo(CGSize.iconImageSize)
      make.top.centerX.equalTo(self)
    }
    
    titleLabel.snp.makeConstraints { make in
      make.top.equalTo(iconImageView.snp.bottom).offset(CGFloat.iconImageBottomPadding)
      make.centerX.equalTo(self)
    }
    
    subtitleLabel.snp.makeConstraints { make in
      make.top.equalTo(titleLabel.snp.bottom).offset(CGFloat.interLabelPadding)
      make.centerX.equalTo(self)
    }
  }
}

private extension CGSize {
  static let iconImageSize = CGSize(width: 72, height: 72)
}

private extension CGFloat {
  static let iconImageCornerRadius: CGFloat = 20
  static let iconImageBottomPadding: CGFloat = 20
  static let interLabelPadding: CGFloat = 4
  static let subtitleLabelBottomPadding: CGFloat = 32
}
