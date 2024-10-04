import UIKit
import TKUIKit
import TKCore

final class StakingInputBalanceView: UIView {
  let maxButton = TKButton()
  let balanceLabel = UILabel()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.alignment = .center
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension StakingInputBalanceView {
  func setup() {
    addSubview(stackView)
    
    maxButton.setContentHuggingPriority(.required, for: .horizontal)
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    stackView.addArrangedSubview(maxButton)
    stackView.addArrangedSubview(balanceLabel)
  }
}
