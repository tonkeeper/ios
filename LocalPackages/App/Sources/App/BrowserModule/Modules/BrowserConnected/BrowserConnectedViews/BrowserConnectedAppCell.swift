import UIKit
import TKUIKit

final class BrowserConnectedAppCell: UICollectionViewCell, ReusableView, TKConfigurableView {
  
  var didLongPress: (() -> Void)?
  
  let iconImageView = UIImageView()
  let titleLabel = UILabel()
  
  override var isHighlighted: Bool {
    didSet {
      alpha = isHighlighted ? 0.48 : 1
    }
  }
  
  private var imageDownloadTask: ImageDownloadTask?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    imageDownloadTask?.cancel()
    imageDownloadTask?.start(
      imageView: iconImageView,
      size: CGSize(width: 64, height: 64),
      cornerRadius: 16
    )
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    imageDownloadTask?.cancel()
    imageDownloadTask = nil
    iconImageView.image = nil
  }
  
  struct Configuration: Hashable {
    let title: NSAttributedString
    let iconUrl: URL?
    let iconDownloadTask: ImageDownloadTask
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(title)
      hasher.combine(iconUrl)
    }
    
    static func ==(lhs: Configuration, rhs: Configuration) -> Bool {
      return lhs.title == rhs.title && lhs.iconUrl == rhs.iconUrl
    }
    
    init(title: String, iconUrl: URL?, iconDownloadTask: ImageDownloadTask) {
      self.title = title.withTextStyle(
        .body3,
        color: .Text.secondary,
        alignment: .center,
        lineBreakMode: .byTruncatingTail
      )
      self.iconUrl = iconUrl
      self.iconDownloadTask = iconDownloadTask
    }
  }
  
  func configure(configuration: Configuration) {
    titleLabel.attributedText = configuration.title
    imageDownloadTask = configuration.iconDownloadTask
    setNeedsLayout()
  }
}

private extension BrowserConnectedAppCell {
  func setup() {
    addSubview(titleLabel)
    addSubview(iconImageView)
    
    iconImageView.snp.makeConstraints { make in
      make.top.equalTo(self)
      make.centerX.equalTo(self)
      make.size.equalTo(64)
    }
    
    titleLabel.snp.makeConstraints { make in
      make.top.equalTo(iconImageView.snp.bottom)
      make.left.right.equalTo(self)
      make.bottom.equalTo(self).offset(-8)
    }
    
    let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressGestureHandler(recognizer:)))
    longPressGesture.minimumPressDuration = 0.5
    addGestureRecognizer(longPressGesture)
  }
  
  @objc
  func longPressGestureHandler(recognizer: UILongPressGestureRecognizer) {
    switch recognizer.state {
    case .began:
      didLongPress?()
    default:
      break
    }
  }
}
