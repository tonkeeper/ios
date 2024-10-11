import UIKit

final class BalanceHeaderBatteryButton: UIControl {
  
  struct Configuration {
    let batteryConfiguration: BatteryView.State
    let action: (() -> Void)
  }
  
  override var isHighlighted: Bool {
    didSet {
      batteryView.alpha = isHighlighted ? 0.44 : 1
    }
  }
  
  var configuration = Configuration(batteryConfiguration: .empty, action: {}) {
    didSet {
      batteryView.state = configuration.batteryConfiguration
    }
  }
  
  private let batteryView = BatteryView(size: .size34)
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    batteryView.isUserInteractionEnabled = false
    addSubview(batteryView)
    
    batteryView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(UIEdgeInsets(top: 10, left: 0, bottom: 12, right: 24))
    }
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.configuration.action()
    }), for: .touchUpInside)
  }
}
