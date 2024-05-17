import UIKit
import TKUIKit
import TKCore

final class StakingAmountView: UIView {
  let amountInputView = StakingAmountInputView()
  let balanceView = StakingBalanceView()
  
  private let rootVStack: UIStackView = {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = .spacing
    
    return stack
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension StakingAmountView {
  func setup() {
    rootVStack.addArrangedSubview(amountInputView)
    rootVStack.addArrangedSubview(balanceView)
    
    rootVStack.fill(in: self)
    
    amountInputView.snp.makeConstraints {
      $0.height.equalTo(CGFloat.amountViewHeight)
    }
  }
}

private extension CGFloat {
  static let spacing: Self = 16
  static let amountViewHeight: Self = 188
}
