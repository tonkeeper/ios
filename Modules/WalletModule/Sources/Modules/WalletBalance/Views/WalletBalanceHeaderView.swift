import UIKit
import TKUIKit

final class WalletBalanceHeaderView: UIView, ConfigurableView {
  
  let balanceView = WalletBalanceHeaderBalanceView()
  let buttonsView = WalletBalanceHeaderButtonsView()
  
  private let stackView: UIStackView = {
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
    let balanceViewModel: WalletBalanceHeaderBalanceView.Model
    let buttonsViewModel: WalletBalanceHeaderButtonsView.Model
  }
  
  func configure(model: Model) {
    balanceView.configure(model: model.balanceViewModel)
    buttonsView.configure(model: model.buttonsViewModel)
  }
}

private extension WalletBalanceHeaderView {
  func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(balanceView)
    stackView.addArrangedSubview(buttonsView)
    
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
