import UIKit
import TKUIKit

final class TonChartHeaderView: UIView, ConfigurableView {
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  private let diffStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 8
    return stackView
  }()
  
  let amountLabel = UILabel()
  let percentDiffLabel = UILabel()
  let fiatDiffLabel = UILabel()
  let dateLabel = UILabel()
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 94)
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let amount: NSAttributedString?
    let percentDiff: NSAttributedString?
    let fiatDiff: NSAttributedString?
    let date: NSAttributedString?
  }
  
  func configure(model: Model) {
    amountLabel.attributedText = model.amount
    percentDiffLabel.attributedText = model.percentDiff
    fiatDiffLabel.attributedText = model.fiatDiff
    dateLabel.attributedText = model.date
  }
}

private extension TonChartHeaderView {
  func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(amountLabel)
    stackView.addArrangedSubview(diffStackView)
    stackView.addArrangedSubview(dateLabel)
    diffStackView.addArrangedSubview(percentDiffLabel)
    diffStackView.addArrangedSubview(fiatDiffLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    percentDiffLabel.setContentHuggingPriority(.required, for: .horizontal)
    
    stackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor, constant: .stackViewTopSpacing),
      stackView.leftAnchor.constraint(equalTo: leftAnchor, constant: .stackViewLeftSpacing),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
}

private extension CGFloat {
  static let stackViewTopSpacing: CGFloat = 26
  static let stackViewLeftSpacing: CGFloat = 28
}
