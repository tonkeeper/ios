import UIKit
import TKUIKit

final class WalletsListFooterView: UIView, ConfigurableView {
  
  private let addWalletButton: TKButton = {
    var configuration = TKButton.Configuration.actionButtonConfiguration(
      category: .secondary,
      size: .small
    )
    configuration.padding.top = 16
    configuration.padding.bottom = 16
    return TKButton(configuration: configuration)
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let content: TKButton.Configuration.Content
    let action: () -> Void
  }
  
  func configure(model: Model) {
    addWalletButton.configuration.content = model.content
    addWalletButton.configuration.action = model.action
  }
}

private extension WalletsListFooterView {
  func setup() {
    addSubview(addWalletButton)
    setupConstraints()
  }
  
  func setupConstraints() {
    addWalletButton.snp.makeConstraints { make in
      make.edges.equalTo(self).priority(.low)
      make.centerX.equalTo(self)
    }
  }
}
