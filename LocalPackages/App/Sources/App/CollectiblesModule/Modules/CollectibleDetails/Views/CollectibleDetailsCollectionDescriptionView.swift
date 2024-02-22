import UIKit
import TKUIKit

final class CollectibleDetailsCollectionDescriptionView: UIView, ConfigurableView {
  
  let titleLabel = UILabel()
  
  let descriptionView: MoreTextViewContainer = {
    let view = MoreTextViewContainer()
    view.numberOfLinesInCollapsed = 3
    return view
  }()
  
  private let contentView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let title: String?
    let description: String?
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title?.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    descriptionView.text = model.description
  }
}

private extension CollectibleDetailsCollectionDescriptionView {
  func setup() {
    addSubview(contentView)
    contentView.addSubview(titleLabel)
    contentView.addSubview(descriptionView)
    
    contentView.backgroundColor = .Background.content
    contentView.layer.cornerRadius = 16
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentView.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    descriptionView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: topAnchor),
      contentView.leftAnchor.constraint(equalTo: leftAnchor),
      contentView.rightAnchor.constraint(equalTo: rightAnchor),
      contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
      titleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 16),
      titleLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -16),
      
      descriptionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: .descriptionTopSpace),
      descriptionView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 16),
      descriptionView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -16),
      descriptionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
    ])
  }
}

private extension CGFloat {
  static let descriptionTopSpace: CGFloat = 8
}
