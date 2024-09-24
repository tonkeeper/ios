import UIKit
import TKUIKit
import SnapKit

final class BalanceHeaderView: UIView, ConfigurableView {
  
  private let balanceView = BalanceHeaderBalanceView()
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
    let balanceModel: BalanceHeaderBalanceView.Model
    let buttonsViewModel: WalletBalanceHeaderButtonsView.Model
  }
  
  func configure(model: Model) {
    balanceView.configure(model: model.balanceModel)
    buttonsView.configure(model: model.buttonsViewModel)
  }
  
//  override var intrinsicContentSize: CGSize {
//    CGSize(width: UIView.noIntrinsicMetric, height: 400)
//  }
}

private extension BalanceHeaderView {
  func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(balanceView)
    stackView.addArrangedSubview(buttonsView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
