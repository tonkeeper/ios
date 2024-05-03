import UIKit
import TKUIKit

final class SettingsListFooterCell: UICollectionViewCell, ConfigurableView {
  
  let topLabel = UILabel()
  let bottomLabel = UILabel()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 2
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
    return stackView
  }()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  struct Model: Hashable {
    let top: String
    let bottom: String
  }
  
  func configure(model: Model) {
    topLabel.attributedText = model.top
      .withTextStyle(.label2, color: .Text.primary, alignment: .center)
    bottomLabel.attributedText = model.bottom
      .withTextStyle(.body3, color: .Text.secondary, alignment: .center)
  }
}

private extension SettingsListFooterCell {
  func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(topLabel)
    stackView.addArrangedSubview(bottomLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
