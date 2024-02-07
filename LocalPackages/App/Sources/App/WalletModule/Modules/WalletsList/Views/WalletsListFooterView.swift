import UIKit
import TKUIKit

final class WalletsListFooterView: UIView, ConfigurableView {
  
  let addWalletButton = TKUIHeaderTitleIconButton()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let addWalletButtonModel: TKUIHeaderTitleIconButton.Model
    let addWalletButtonAction: () -> Void
  }
  
  func configure(model: Model) {
    addWalletButton.configure(model: model.addWalletButtonModel)
    addWalletButton.addTapAction(model.addWalletButtonAction)
  }
}

private extension WalletsListFooterView {
  func setup() {
    addWalletButton.padding.top = 16
    addWalletButton.padding.bottom = 16
    
    addSubview(addWalletButton)
    setupConstraints()
  }
  
  func setupConstraints() {
    addWalletButton.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      addWalletButton.topAnchor.constraint(equalTo: topAnchor),
      addWalletButton.leftAnchor.constraint(greaterThanOrEqualTo: leftAnchor),
      addWalletButton.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh),
      addWalletButton.rightAnchor.constraint(lessThanOrEqualTo: rightAnchor).withPriority(.defaultHigh),
      addWalletButton.centerXAnchor.constraint(equalTo: centerXAnchor)
    ])
  }
}
