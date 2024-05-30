import UIKit
import TKUIKit

final class StakeFooterView: UIView, ConfigurableView {
  
  let maxButton = TKButton(
    configuration: .iconHeaderButtonConfiguration(
      contentPadding: .maxButtonContentPadding,
      padding: .zero
    )
  )
  
  let descriptionLabel = UILabel()
  
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.distribution = .equalSpacing
    return stackView
  }()
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: .height)
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    struct Button {
      let title: String
      let isEnabled: Bool
      let action: (() -> Void)
    }
    
    let maxButton: Button
    let description: NSAttributedString
  }
  
  func configure(model: Model) {
    maxButton.configuration.content.title = .attributedString(model.maxButton.title.withTextStyle(.label2, color: .Button.secondaryForeground))
    maxButton.isEnabled = model.maxButton.isEnabled
    maxButton.configuration.action = model.maxButton.action
    descriptionLabel.attributedText = model.description
  }
}

private extension StakeFooterView {
  func setup() {
    contentStackView.addArrangedSubview(maxButton)
    contentStackView.addArrangedSubview(descriptionLabel)
    addSubview(contentStackView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentStackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}

private extension CGFloat {
  static let height: CGFloat = 36
}

private extension UIEdgeInsets {
  static let maxButtonContentPadding = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
}
