import UIKit
import TKUIKit
import TKCore

final class StakingConfirmationHeaderView: UIView, ConfigurableView {
  var imageLoader: ImageLoader?
  let imageView = UIImageView()
  
  private let imageContainer = UIView()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let image: Image
  }
  
  func configure(model: Model) {
    switch model.image {
    case .image(let image, let tintColor, let backgroundColor):
      imageView.image = image
      imageView.tintColor = tintColor
      imageView.backgroundColor = backgroundColor
    case .url(let url):
      _ = imageLoader?.loadImage(url: url, imageView: imageView, size: nil)
    }
  }
}

// MARK: - Private methods

private extension StakingConfirmationHeaderView {
  func setup() {
    imageView.layer.masksToBounds = true
    imageView.layer.cornerRadius = .imageWidth/2
    
    imageContainer.layout(in: self) {
      $0.top.equalToSuperview()
      $0.centerX.equalToSuperview()
      $0.bottom.equalToSuperview()
      $0.width.height.equalTo(CGFloat.imageWidth)
    }
    
    imageView.fill(in: imageContainer)
  }
}

private extension CGFloat {
  static let imageWidth: Self = 96
}
