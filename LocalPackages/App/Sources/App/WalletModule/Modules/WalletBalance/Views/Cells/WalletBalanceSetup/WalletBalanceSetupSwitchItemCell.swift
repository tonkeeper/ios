import UIKit
import TKUIKit

final class WalletBalanceSetupSwitchItemCell: TKCollectionViewContainerCell<WalletBalanceSetupSwitchItemCellContentView> {
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .Background.content
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

final class WalletBalanceSetupSwitchItemCellContentView: UIView, ConfigurableView, TKCollectionViewCellContentView, ReusableView {
  var padding: UIEdgeInsets { .init(top: 16, left: 16, bottom: 16, right: 16) }
  
  let iconView = TKListItemIconImageView()
  let contentView = WalletBalanceSetupContentView()
  let valueView = TKListItemSwitchView()
  
  lazy var layout = TKListItemLayout(iconView: iconView, contentView: contentView, valueView: valueView)
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    layout.layouSubviews(bounds: bounds)
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return layout.calculateSize(targetSize: size)
  }
  
  struct Model {
    let iconModel: TKListItemIconImageView.Model
    let contentModel: WalletBalanceSetupContentView.Model
    let valueModel: TKListItemSwitchView.Model
  }
  
  func configure(model: Model) {
    iconView.configure(model: model.iconModel)
    contentView.configure(model: model.contentModel)
    valueView.configure(model: model.valueModel)
  }
  
  func prepareForReuse() {
    iconView.prepareForReuse()
    contentView.prepareForReuse()
  }
}

private extension WalletBalanceSetupSwitchItemCellContentView {
  func setup() {
    addSubview(iconView)
    addSubview(contentView)
    addSubview(valueView)
  }
}
