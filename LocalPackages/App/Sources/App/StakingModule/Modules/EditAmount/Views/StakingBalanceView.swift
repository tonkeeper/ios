import UIKit
import TKUIKit
import TKCore

final class StakingBalanceView: UIView {
  let button = TKButton()
  let label = UILabel()
  
  private lazy var rootHStack: UIStackView = {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.alignment = .center
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

private extension StakingBalanceView {
  func setup() {
    button.setContentHuggingPriority(.required, for: .horizontal)
    
    rootHStack.fill(in: self)
    
    rootHStack.addArrangedSubview(button)
    rootHStack.addArrangedSubview(label)
  }
}
