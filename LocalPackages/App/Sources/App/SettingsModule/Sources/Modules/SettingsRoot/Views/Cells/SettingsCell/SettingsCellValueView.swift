import UIKit
import TKUIKit

final class SettingsCellValueView: UIView, ConfigurableView, ReusableView {
  
//  private let valueContainer = UIView()
  private var contentView: ReusableView?
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public  init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
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
    case icon(SettingsCellIconValueView.Model)
  }
  
  public func configure(model: Model) {
    contentView?.removeFromSuperview()
    switch model {
    case .icon(let model):
      let view = SettingsCellIconValueView()
      view.configure(model: model)
      addSubview(view)
      contentView = view
    }
  }
}

private extension SettingsCellValueView {
  func setup() {
//    addSubview(valueContainer)
  }
}

