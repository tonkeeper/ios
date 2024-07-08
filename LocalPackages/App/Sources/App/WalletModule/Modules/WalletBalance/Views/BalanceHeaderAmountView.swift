import TKUIKit
import UIKit
import SnapKit

final class BalanceHeaderAmountView: UIControl, ConfigurableView {
  
  private let balanceButton = BalanceHeaderAmountButton()
  private let backupButton = TKButton()
  
  private var balanceButtonRightConstrant: Constraint?
  private var balanceButtonRightBackupConstrant: Constraint?
  
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
      backupButton.configuration.action = nil
      balanceButtonRightBackupConstrant?.deactivate()
      balanceButtonRightConstrant?.activate()
    case .backup(let closure):
      backupButton.isHidden = false
      backupButton.configuration.action = closure
      balanceButtonRightConstrant?.deactivate()
      balanceButtonRightBackupConstrant?.activate()
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
    
    backupButton.isHidden = true
    
    backupButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    addSubview(balanceButton)
    addSubview(backupButton)
    
    balanceButton.snp.makeConstraints { make in
      make.centerX.equalTo(self).priority(.high)
      make.centerY.equalTo(self)
      make.left.greaterThanOrEqualTo(self)
      balanceButtonRightConstrant = make.right.equalTo(self).constraint
      balanceButtonRightBackupConstrant = make.right.equalTo(backupButton.snp.left).constraint
    }
    
    balanceButtonRightBackupConstrant?.deactivate()
    
    backupButton.snp.makeConstraints { make in
      make.centerY.equalTo(balanceButton)
      make.right.lessThanOrEqualTo(self)
    }
  }
}
