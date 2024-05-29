import UIKit
import TKUIKit
import TKCore
import SnapKit

final class HistoryEventDetailsNFTHeaderImageView: UIView, ConfigurableView {
  
  var imageLoader: ImageLoader?
  
  let imageView = UIImageView()
  
  private let imageContainer = UIView()
  private var imageSize: CGSize = .zero {
    didSet {
      imageView.snp.updateConstraints { make in
        make.width.height.equalTo(imageSize)
      }
    }
  }
  
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
    let image: EnumImage
    let size: CGSize
  }
  
  func configure(model: Model) {
    self.imageSize = model.size
    switch model.image {
    case .image(let image, let tintColor, let backgroundColor):
      imageView.image = image
      imageView.tintColor = tintColor
      imageView.backgroundColor = backgroundColor
    case .url(let url):
      _ = imageLoader?.loadImage(url: url, imageView: imageView, size: model.size)
    }
  }
}

private extension HistoryEventDetailsNFTHeaderImageView {
  func setup() {
    imageView.contentMode = .scaleAspectFit
    imageView.layer.masksToBounds = true
    imageView.layer.cornerRadius = 20
    imageView.backgroundColor = .Background.content
    
    addSubview(imageContainer)
    imageContainer.addSubview(imageView)
    setupConstraints()
  }
  
  func setupConstraints() {
    imageContainer.snp.makeConstraints { make in
      make.top.centerX.bottom.equalTo(self)
    }
    
    imageView.snp.makeConstraints { make in
      make.width.height.equalTo(imageSize)
      make.left.top.bottom.right.equalTo(imageContainer)
    }
  }
}
