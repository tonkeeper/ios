import UIKit
import TKUIKit

final class AmountInputBalanceView: UIView {
  
  struct Configuration {
    let maxButtonConfiguration: TKButton.Configuration?
    let balance: NSAttributedString
  }
  
  var configuration: Configuration? {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
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
  
  private func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(maxButton)
    stackView.addArrangedSubview(balanceLabel)
    
    maxButton.setContentHuggingPriority(.required, for: .horizontal)
    maxButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    balanceLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
  
  private func didUpdateConfiguration() {
    guard let configuration else {
      maxButton.configuration = TKButton.Configuration()
      maxButton.isHidden = true
      balanceLabel.text = nil
      return
    }
    
    if let maxButtonConfiguration = configuration.maxButtonConfiguration {
      maxButton.configuration = maxButtonConfiguration
      maxButton.isHidden = false
    } else {
      maxButton.configuration = TKButton.Configuration()
      maxButton.isHidden = true
    }
    
    balanceLabel.attributedText = configuration.balance
  }
}
