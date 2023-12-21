import UIKit

final class SwapHeaderImageView: UIView, ConfigurableView {
  
  var imageLoader: ImageLoader?
  
  let leftImageView = UIImageView()
  let rightImageView = UIImageView()
  
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
    let leftImage: Image
    let rightImage: Image
  }
  
  func configure(model: Model) {
    switch model.leftImage {
    case .image(let image, let tintColor, let backgroundColor):
      leftImageView.image = image
      leftImageView.tintColor = tintColor
      leftImageView.backgroundColor = backgroundColor
    case .url(let url):
      imageLoader?.loadImage(imageURL: url, imageView: leftImageView, size: nil)
    }
    
    switch model.rightImage {
    case .image(let image, let tintColor, let backgroundColor):
      rightImageView.image = image
      rightImageView.tintColor = tintColor
      rightImageView.backgroundColor = backgroundColor
    case .url(let url):
      imageLoader?.loadImage(imageURL: url, imageView: rightImageView, size: nil)
    }
  }
}

private extension SwapHeaderImageView {
  func setup() {
    leftImageView.layer.masksToBounds = true
    leftImageView.layer.cornerRadius = 38
    leftImageView.layer.borderWidth = 4
    leftImageView.layer.borderColor = UIColor.Background.page.cgColor
    rightImageView.layer.masksToBounds = true
    rightImageView.layer.cornerRadius = 38
    rightImageView.layer.borderWidth = 4
    rightImageView.layer.borderColor = UIColor.Background.page.cgColor
    
    addSubview(imageContainer)
    imageContainer.addSubview(leftImageView)
    imageContainer.addSubview(rightImageView)
    setupConstraints()
  }
  
  func setupConstraints() {
    imageContainer.translatesAutoresizingMaskIntoConstraints = false
    leftImageView.translatesAutoresizingMaskIntoConstraints = false
    rightImageView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      imageContainer.topAnchor.constraint(equalTo: topAnchor),
      imageContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
      imageContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      leftImageView.widthAnchor.constraint(equalToConstant: 76),
      leftImageView.heightAnchor.constraint(equalToConstant: 76),
      leftImageView.leftAnchor.constraint(equalTo: imageContainer.leftAnchor),
      leftImageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
      leftImageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
      
      rightImageView.widthAnchor.constraint(equalToConstant: 76),
      rightImageView.heightAnchor.constraint(equalToConstant: 76),
      rightImageView.rightAnchor.constraint(equalTo: imageContainer.rightAnchor),
      rightImageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
      rightImageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
      rightImageView.leftAnchor.constraint(equalTo: leftImageView.rightAnchor, constant: -16)
    ])
  }
}
