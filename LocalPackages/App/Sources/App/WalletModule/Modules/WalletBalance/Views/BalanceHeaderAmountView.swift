import TKUIKit
import UIKit
import SnapKit

final class BalanceHeaderAmountView: UIControl {
  
  struct Configuration {
    enum Backup {
      case none
      case backup(color: UIColor, closure: () -> Void)
    }
    let balanceButtonModel: BalanceHeaderAmountButton.Model
    let batteryButtonConfiguration: BalanceHeaderBatteryButton.Configuration?
    let backup: Backup
  }
  
  var configuration: Configuration? {
    didSet {
      didUpdateConfiguration()
    }
  }
  
  private let balanceButton = BalanceHeaderAmountButton()
  private let batteryButton = BalanceHeaderBatteryButton()
  private let backupButton = TKButton()
  private let stackView = UIStackView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    setupBackupButton()
    
    stackView.alignment = .center
    
    addSubview(stackView)
    stackView.addArrangedSubview(balanceButton)
    stackView.addArrangedSubview(backupButton)
    stackView.addArrangedSubview(batteryButton)
    
    stackView.snp.makeConstraints { make in
      make.centerX.equalTo(self)
      make.centerY.equalTo(self)
    }
  }
  
  private func didUpdateConfiguration() {
    guard let configuration = configuration else {
      return
    }
    balanceButton.configure(model: configuration.balanceButtonModel)
    
    switch configuration.backup {
    case .none:
      backupButton.isHidden = true
      backupButton.configuration.action = nil
    case .backup(let color, let closure):
      backupButton.isHidden = false
      backupButton.configuration.action = closure
      backupButton.configuration.iconTintColor = color
      backupButton.configuration.backgroundColors = [.normal: color.withAlphaComponent(0.48),
                                                     .highlighted: color.withAlphaComponent(0.48)]
    }
    
    if let batteryButtonConfiguration = configuration.batteryButtonConfiguration {
      batteryButton.isHidden = false
      batteryButton.configuration = batteryButtonConfiguration
    } else {
      batteryButton.isHidden = true
    }
    
    stackView.setCustomSpacing(backupButton.isHidden ? 8 : 0, after: balanceButton)
  }
  
  private func setupBackupButton() {
    backupButton.configuration.content = TKButton.Configuration.Content(icon: .TKUIKit.Icons.Size12.informationCircle)
    backupButton.configuration.backgroundColors = [.normal: .Accent.orange.withAlphaComponent(0.48),
                                                   .highlighted: .Accent.orange.withAlphaComponent(0.48)]
    backupButton.configuration.contentPadding = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
    backupButton.configuration.padding = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    backupButton.configuration.cornerRadius = 10
    backupButton.configuration.iconTintColor = .Accent.orange
    backupButton.configuration.contentAlpha = [.highlighted: 0.48]
    
    backupButton.isHidden = true
  }
}
