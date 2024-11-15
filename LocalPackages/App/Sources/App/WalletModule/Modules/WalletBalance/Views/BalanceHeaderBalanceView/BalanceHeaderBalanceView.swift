import UIKit
import TKUIKit
import SnapKit

final class BalanceHeaderBalanceView: UIView, ConfigurableView {
  
  private let balanceView = BalanceHeaderAmountView()
  private let statusView = BalanceHeaderBalanceStatusView()
  private let stackView = UIStackView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  struct Model {
    let balanceConfiguration: BalanceHeaderAmountView.Configuration
    let statusViewConfiguration: BalanceHeaderBalanceStatusView.Configuration
  }
  
  func configure(model: Model) {
    balanceView.configuration = model.balanceConfiguration
    statusView.configuration = model.statusViewConfiguration
  }
}

private extension BalanceHeaderBalanceView {
  func setup() {
    stackView.axis = .vertical
    stackView.addArrangedSubview(balanceView)
    stackView.addArrangedSubview(TKSpacingView(verticalSpacing: .constant(4)))
    stackView.addArrangedSubview(statusView)
    stackView.addArrangedSubview(TKSpacingView(verticalSpacing: .constant(8)))
    
    addSubview(stackView)
    setupConstraints()
  }
  
  func setupConstraints() {
    balanceView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.balanceLabelHeight)
    }
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(UIEdgeInsets.stackViewPadding)
    }
  }
}

private extension CGFloat {
  static let balanceLabelHeight: CGFloat = 56
}

private extension UIEdgeInsets {
  static var stackViewPadding = UIEdgeInsets(top: 28, left: 16, bottom: 16, right: 16)
}
