import UIKit
import TKUIKit

final class NFTDetailsItemInformationView: UIView, ConfigurableView {
  
  struct Model {
    let name: String?
    let collectionName: String?
    let isCollectionVerified: Bool
    let itemDescriptionModel: NFTDetailsMoreTextView.Model
  }
  
  func configure(model: Model) {
    nameLabel.attributedText = model.name?.withTextStyle(
      .h2,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    collectionNameLabel.attributedText = model.collectionName?.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    collectionVerificationImageView.isHidden = !model.isCollectionVerified
    itemDescriptionView.configure(model: model.itemDescriptionModel)
  }
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 4
    stackView.alignment = .leading
    return stackView
  }()
  private let nameLabel = UILabel()
  private let titleStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.alignment = .center
    return stackView
  }()
  private let collectionNameLabel = UILabel()
  private let collectionVerificationImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .center
    imageView.image = .TKUIKit.Icons.Size16.verificationBlueTint
    return imageView
  }()
  private let collectionStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.alignment = .center
    stackView.spacing = 4
    return stackView
  }()
  private let itemDescriptionView = NFTDetailsMoreTextView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    nameLabel.numberOfLines = 0
    
    addSubview(stackView)
    
    stackView.addArrangedSubview(titleStackView)
    titleStackView.addArrangedSubview(nameLabel)
    
    stackView.addArrangedSubview(collectionStackView)
    collectionStackView.addArrangedSubview(collectionNameLabel)
    collectionStackView.addArrangedSubview(collectionVerificationImageView)
    
    stackView.addArrangedSubview(itemDescriptionView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(
        UIEdgeInsets(
          top: 14,
          left: 16,
          bottom: 14,
          right: 16
        )
      )
    }
    
    itemDescriptionView.snp.makeConstraints { make in
      make.width.equalTo(stackView)
    }
  }
}
