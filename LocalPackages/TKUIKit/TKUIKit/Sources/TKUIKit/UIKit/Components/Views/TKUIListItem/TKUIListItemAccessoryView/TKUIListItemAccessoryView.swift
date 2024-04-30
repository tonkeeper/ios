import UIKit

public final class TKUIListItemAccessoryView: UIView, TKConfigurableView {
  
  private var accessoryView: UIView?

  public enum Configuration: Hashable {
    case none
    case switchControl(TKUIListItemSwitchAccessoryView.Configuration)
    case image(TKUIListItemImageAccessoryView.Configuration)
    case text(TKUIListItemTextAccessoryView.Configuration)
  }
  
  public func configure(configuration: Configuration) {
    accessoryView?.removeFromSuperview()
    switch configuration {
    case .switchControl(let configuration):
      let switchAccessoryView = TKUIListItemSwitchAccessoryView()
      switchAccessoryView.configure(configuration: configuration)
      addSubview(switchAccessoryView)
      accessoryView = switchAccessoryView
    case .image(let configuration):
      let imageAccessoryView = TKUIListItemImageAccessoryView()
      imageAccessoryView.configure(configuration: configuration)
      addSubview(imageAccessoryView)
      accessoryView = imageAccessoryView
    case .text(let configuration):
      let textAccessoryView = TKUIListItemTextAccessoryView()
      textAccessoryView.configure(configuration: configuration)
      addSubview(textAccessoryView)
      accessoryView = textAccessoryView
    case .none:
      accessoryView = nil
    }
    setNeedsLayout()
  }

  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    guard let accessoryView = accessoryView else { return .zero }
    return accessoryView.sizeThatFits(size)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    if let accessoryView = accessoryView {
      accessoryView.sizeToFit()
      accessoryView.center = CGPoint(x: bounds.width/2,
                                     y: bounds.height/2)
    }
  }
}

private extension TKUIListItemAccessoryView {}
