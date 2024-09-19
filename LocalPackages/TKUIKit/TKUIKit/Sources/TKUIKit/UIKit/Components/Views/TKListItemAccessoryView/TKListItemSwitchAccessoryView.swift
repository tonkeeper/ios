import UIKit

public final class TKListItemSwitchAccessoryView: UIControl {
  
  public struct Configuration {
    public let isOn: Bool
    public let isEnable: Bool
    public let action: ((_ isOn: Bool) -> Void)?
    
    public static var `default`: Configuration {
      Configuration(isOn: false, action: nil)
    }
    
    public init(isOn: Bool,
                isEnable: Bool = true,
                action: ((_ isOn: Bool) -> Void)?) {
      self.isOn = isOn
      self.isEnable = isEnable
      self.action = action
    }
  }
  
  public var configuration: Configuration = .default {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  private let `switch` = UISwitch()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let sizeThatFits = `switch`.sizeThatFits(.zero)
    `switch`.frame = CGRect(x: 0, y: 0, width: sizeThatFits.width, height: bounds.height)
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let sizeThatFits = `switch`.sizeThatFits(.zero)
    return CGSize(width: sizeThatFits.width + 16, height: sizeThatFits.height)
  }
  
  private func setup() {
    `switch`.onTintColor = .Accent.blue
    `switch`.addAction(UIAction(handler: { [weak self] _ in
      self?.configuration.action?(self?.`switch`.isOn ?? false)
    }), for: .valueChanged)
    
    addSubview(`switch`)
    
    didUpdateConfiguration()
  }
  
  private func didUpdateConfiguration() {
    `switch`.isOn = configuration.isOn
    `switch`.isEnabled = configuration.isEnable
  }
}
