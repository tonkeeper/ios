import UIKit

public final class TKUIListItemSwitchAccessoryView: UIView, TKConfigurableView {
  public typealias SwitchHandlerClosure = ((Bool) async -> Bool)
  
  let switchControl = UISwitch()
  
  private var handler: SwitchHandlerClosure?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Configuration: Hashable {
    public let isOn: Bool
    public let handler: SwitchHandlerClosure
    
    public init(isOn: Bool, handler: @escaping SwitchHandlerClosure) {
      self.isOn = isOn
      self.handler = handler
    }
    
    public static func == (lhs: TKUIListItemSwitchAccessoryView.Configuration,
                           rhs: TKUIListItemSwitchAccessoryView.Configuration) -> Bool {
      lhs.isOn == rhs.isOn
    }
    
    public func hash(into hasher: inout Hasher) {
      hasher.combine(isOn)
    }
  }
  
  public func configure(configuration: Configuration) {
    switchControl.isOn = configuration.isOn
    handler = configuration.handler
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    switchControl.sizeThatFits(size)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    switchControl.sizeToFit()
    switchControl.center = CGPoint(x: bounds.width/2,
                                   y: bounds.height/2)
  }
}

private extension TKUIListItemSwitchAccessoryView {
  func setup() {
    switchControl.addAction(UIAction(handler: { [weak self, weak switchControl] _ in
      guard let handler = self?.handler else { return }
      guard let isOn = switchControl?.isOn else { return }
      Task {
        let isSuccess = await handler(isOn)
        await MainActor.run {
          guard !isSuccess else { return }
          switchControl?.setOn(!isOn, animated: true)
        }
      }
    }), for: .valueChanged)
    
    addSubview(switchControl)
  }
}
