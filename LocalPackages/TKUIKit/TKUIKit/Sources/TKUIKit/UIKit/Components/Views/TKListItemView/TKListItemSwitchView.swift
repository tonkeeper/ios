import UIKit

public final class TKListItemSwitchView: UIView, ConfigurableView, ReusableView {
  
  private let switchView = UISwitch()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public  init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    switchView.frame = bounds
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    switchView.sizeThatFits(size)
  }

  public struct Model {
    public let isOn: Bool
    public let isEnabled: Bool
    public let action: (Bool) async -> Bool
    
    public init(isOn: Bool,
                isEnabled: Bool = true,
                action: @escaping (Bool) async -> Bool) {
      self.isOn = isOn
      self.isEnabled = isEnabled
      self.action = action
    }
  }
  
  public func configure(model: Model) {
    switchView.setOn(model.isOn, animated: false)
    switchView.isEnabled = model.isEnabled
    switchView.addAction(.init(handler: { [weak switchView] _ in
      guard let switchView else { return }
      Task {
        let result = await model.action(switchView.isOn)
        Task { @MainActor in
          guard result != switchView.isOn else { return }
          switchView.setOn(result, animated: true)
        }
      }
    }), for: .valueChanged)
  }
}

private extension TKListItemSwitchView {
  func setup() {
    addSubview(switchView)
  }
}
