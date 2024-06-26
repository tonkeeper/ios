import UIKit
import TKUIKit
import TKCore

final class CollectibleDetailsCollectibleView: UIView, ConfigurableView {

  let imageView = UIImageView()
  let titleLabel = UILabel()
  let subtitleLabel = UILabel()
  let descriptionView = MoreTextViewContainer()
  
  var imageLoader = ImageLoader()

  private let contentView = UIView()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = .stackViewSpacing
    return stackView
  }()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  struct Model {
    let title: String?
    let subtitle: String?
    let description: String?
    let imageURL: URL?
  }

  func configure(model: Model) {
    titleLabel.attributedText = model.title?.withTextStyle(
      .h2,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    subtitleLabel.attributedText = model.subtitle?.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    subtitleLabel.isHidden = model.subtitle == nil

    descriptionView.text = model.description
    descriptionView.isHidden = model.description == nil || model.description?.isEmpty == true
    
    _ = imageLoader.loadImage(url: model.imageURL, imageView: imageView, size: nil)
  }
}

private extension CollectibleDetailsCollectibleView {
  func setup() {
    titleLabel.numberOfLines = 0
    
    contentView.backgroundColor = .Background.content
    contentView.layer.cornerRadius = .cornerRadius
    contentView.layer.masksToBounds = true
    
    addSubview(contentView)
    contentView.addSubview(stackView)
    contentView.addSubview(imageView)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(subtitleLabel)
    stackView.addArrangedSubview(descriptionView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentView.translatesAutoresizingMaskIntoConstraints = false
    stackView.translatesAutoresizingMaskIntoConstraints = false
    imageView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: topAnchor),
      contentView.leftAnchor.constraint(equalTo: leftAnchor),
      contentView.rightAnchor.constraint(equalTo: rightAnchor),
      contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
      imageView.leftAnchor.constraint(equalTo: contentView.leftAnchor),
      imageView.rightAnchor.constraint(equalTo: contentView.rightAnchor),
      imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
      
      stackView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: .stackViewTopSpace),
      stackView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 16),
      stackView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -16),
      stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
    ])
  }
}

private extension CGFloat {
  static let stackViewSpacing: CGFloat = 4
  static let stackViewTopSpace: CGFloat = 14
  static let cornerRadius: CGFloat = 16
}

