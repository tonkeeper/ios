import UIKit
import TKUIKit

final class WalletBalanceHeaderBalanceView: UIView, ConfigurableView {
  
  let balanceLabel = UILabel()
  let addressLabel = UIButton(type: .system)
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins.top = .topInset
    stackView.directionalLayoutMargins.bottom = .bottomInset
    return stackView
  }()
  private let addressStatusStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
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
    let balance: String
    let address: String
    let addressAction: () -> Void
  }
  
  func configure(model: Model) {
    balanceLabel.attributedText = model.balance.withTextStyle(
      .balance,
      color: .Text.primary,
      alignment: .center
    )
    addressLabel.setAttributedTitle(
      model.address.withTextStyle(.body2, color: .Text.secondary), 
      for: .normal
    )
    addressLabel.removeTarget(nil, action: nil, for: .touchUpInside)
    addressLabel.addAction(UIAction(handler: { _ in
      model.addressAction()
    }), for: .touchUpInside)
  }
}

private extension WalletBalanceHeaderBalanceView {
  func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(balanceLabel)
    stackView.addArrangedSubview(addressStatusStackView)
    addressStatusStackView.addArrangedSubview(addressLabel)
    
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

private extension CGFloat {
  static let topInset: CGFloat = 28
  static let bottomInset: CGFloat = 16
}
