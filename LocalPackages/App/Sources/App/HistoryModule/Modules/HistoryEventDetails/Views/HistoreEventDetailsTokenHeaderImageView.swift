import UIKit
import TKUIKit
import TKCore

final class HistoreEventDetailsTokenHeaderImageView: UIView, ConfigurableView {
  
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
    let image: EnumImage
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

private extension HistoreEventDetailsTokenHeaderImageView {
  func setup() {
    imageView.layer.masksToBounds = true
    imageView.layer.cornerRadius = 38
    
    addSubview(imageContainer)
    imageContainer.addSubview(imageView)
    setupConstraints()
  }
  
  func setupConstraints() {
    imageContainer.translatesAutoresizingMaskIntoConstraints = false
    imageView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      imageContainer.topAnchor.constraint(equalTo: topAnchor),
      imageContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
      imageContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      imageView.widthAnchor.constraint(equalToConstant: 76),
      imageView.heightAnchor.constraint(equalToConstant: 76),
      imageView.leftAnchor.constraint(equalTo: imageContainer.leftAnchor),
      imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
      imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
      imageView.rightAnchor.constraint(equalTo: imageContainer.rightAnchor),
    ])
  }
}
