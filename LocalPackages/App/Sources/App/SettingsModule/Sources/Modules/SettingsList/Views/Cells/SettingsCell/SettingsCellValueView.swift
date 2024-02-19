import UIKit
import TKUIKit

final class SettingsCellValueView: UIView, ConfigurableView, ReusableView {
  private var contentView: ReusableView?

  public override func layoutSubviews() {
    super.layoutSubviews()
    
    contentView?.frame = bounds
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    contentView?.sizeThatFits(size) ?? .zero
  }
  
  public func prepareForReuse() {
    contentView?.prepareForReuse()
  }

  public enum Model {
    case text(SettingsCellTextValueView.Model)
    case icon(SettingsCellIconValueView.Model)
    case `switch`(TKListItemSwitchView.Model)
  }
  
  public func configure(model: Model) {
    contentView?.removeFromSuperview()
    switch model {
    case .text(let model):
      let view = SettingsCellTextValueView()
      view.configure(model: model)
      addSubview(view)
      contentView = view
    case .icon(let model):
      let view = SettingsCellIconValueView()
      view.configure(model: model)
      addSubview(view)
      contentView = view
    case .switch(let model):
      let view = TKListItemSwitchView()
      view.configure(model: model)
      addSubview(view)
      contentView = view
    }
  }
}
