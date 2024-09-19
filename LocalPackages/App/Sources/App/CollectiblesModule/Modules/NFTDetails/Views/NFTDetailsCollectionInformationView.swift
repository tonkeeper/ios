import UIKit
import TKUIKit

final class NFTDetailsCollectionInformationView: UIView, ConfigurableView {
  
  struct Model {
    let title: String?
    let collectionDescriptionModel: NFTDetailsMoreTextView.Model
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title?.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    collectionDescriptionView.configure(model: model.collectionDescriptionModel)
  }
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 8
    stackView.alignment = .leading
    return stackView
  }()
  private let titleLabel = UILabel()
  private let collectionDescriptionView = NFTDetailsMoreTextView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(stackView)
    
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(collectionDescriptionView)
    
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
    
    collectionDescriptionView.snp.makeConstraints { make in
      make.width.equalTo(stackView)
    }
  }
}
