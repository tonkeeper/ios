import UIKit
import TKUIKit

final class SwapSettingsTitleDecriptionView: UIView, ConfigurableView {
  
  let titleLabel = UILabel()
  let descriptionLabel = UILabel()
  
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.distribution = .fillProportionally
    return stackView
  }()
  
  private let padding: UIEdgeInsets
  
  init(padding: UIEdgeInsets = .init(top: 12, left: 0, bottom: 12, right: 0)) {
    self.padding = padding
    super.init(frame: .zero)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let title: String
    let description: String
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title.withTextStyle(.label1, color: .Text.primary)
    descriptionLabel.attributedText = model.description.withTextStyle(.body2, color: .Text.secondary)
    invalidateIntrinsicContentSize()
  }
}

private extension SwapSettingsTitleDecriptionView {
  func setup() {
    descriptionLabel.numberOfLines = 0
    
    contentStackView.addArrangedSubview(titleLabel)
    contentStackView.addArrangedSubview(descriptionLabel)
    addSubview(contentStackView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentStackView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(padding)
    }
  }
}
