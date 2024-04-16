import UIKit
import TKUIKit

final class TonChartErrorView: UIView, ConfigurableView {
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  let titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    label.textColor = .Text.primary
    label.textAlignment = .center
    label.font = TKTextStyle.label1.font
    return label
  }()
  let subtitleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    label.textColor = .Text.secondary
    label.textAlignment = .center
    label.font = TKTextStyle.body2.font
    return label
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let title: String?
    let subtitle: String?
  }
  
  func configure(model: Model) {
    titleLabel.text = model.title
    subtitleLabel.text = model.subtitle
  }
}

private extension TonChartErrorView {
  func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(subtitleLabel)
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}


