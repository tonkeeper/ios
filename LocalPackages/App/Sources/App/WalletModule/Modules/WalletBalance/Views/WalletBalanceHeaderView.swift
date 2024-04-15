import UIKit
import TKUIKit
import SnapKit

final class WalletBalanceHeaderView: UIView, ConfigurableView {
  
  private let balanceView = WalletBalanceHeaderBalanceView()
  private let buttonsView = WalletBalanceHeaderButtonsView()
  
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
    let balanceModel: WalletBalanceHeaderBalanceView.Model
    let buttonsViewModel: WalletBalanceHeaderButtonsView.Model
  }
  
  func configure(model: Model) {
    balanceView.configure(model: model.balanceModel)
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
//    balanceView.snp.makeConstraints { make in
//      make.top.left.right.bottom.equalTo(self)
//    }
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    
//    stackView.translatesAutoresizingMaskIntoConstraints = false
//    
//    NSLayoutConstraint.activate([
//      stackView.topAnchor.constraint(equalTo: topAnchor),
//      stackView.leftAnchor.constraint(equalTo: leftAnchor),
//      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
//      stackView.rightAnchor.constraint(equalTo: rightAnchor)
//    ])
  }
}
