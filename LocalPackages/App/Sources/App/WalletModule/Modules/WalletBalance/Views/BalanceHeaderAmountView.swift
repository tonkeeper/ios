import TKUIKit
import UIKit
import SnapKit

final class BalanceHeaderAmountView: UIControl, ConfigurableView {
  
  private let balanceButton = BalanceHeaderAmountButton()
  private let backupButton = TKButton()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    enum Backup {
      case none
      case backup(closure: () -> Void)
    }
    let balanceButtonModel: BalanceHeaderAmountButton.Model
    let backup: Backup
  }
  
  func configure(model: Model) {
    balanceButton.configure(model: model.balanceButtonModel)
    switch model.backup {
    case .none:
      backupButton.isHidden = true
    case .backup(let closure):
      backupButton.isHidden = false
    }
  }
  
  private func setup() {
    backupButton.configuration.content = TKButton.Configuration.Content(icon: .TKUIKit.Icons.Size12.informationCircle)
    backupButton.configuration.backgroundColors = [.normal: .Accent.orange.withAlphaComponent(0.48),
                                                   .highlighted: .Accent.orange.withAlphaComponent(0.48)]
    backupButton.configuration.contentPadding = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
    backupButton.configuration.padding = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    backupButton.configuration.cornerRadius = 10
    backupButton.configuration.iconTintColor = .Accent.orange
    backupButton.configuration.contentAlpha = [.highlighted: 0.48]
    
    backupButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    addSubview(balanceButton)
    addSubview(backupButton)
    
    balanceButton.snp.makeConstraints { make in
      make.centerX.equalTo(self)
      make.centerY.equalTo(self)
      make.left.greaterThanOrEqualTo(self)
    }
    
    backupButton.snp.makeConstraints { make in
      make.centerY.equalTo(balanceButton)
      make.left.equalTo(balanceButton.snp.right)
      make.right.lessThanOrEqualTo(self)
    }
  }
}
