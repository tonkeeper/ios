import UIKit
import TKUIKit

final class WalletsListAddWalletCell: UICollectionViewCell, ConfigurableView {
  
  var didTapButton: (() -> Void)?
  
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
  
  struct Model: Hashable {
    let content: TKButton.Configuration.Content
  }
  
  func configure(model: Model) {
    addWalletButton.configuration.content = model.content
    addWalletButton.configuration.action = { [weak self] in
      self?.didTapButton?()
    }
  }
}

private extension WalletsListAddWalletCell {
  func setup() {
    addSubview(addWalletButton)
    setupConstraints()
  }
  
  func setupConstraints() {
    addWalletButton.snp.makeConstraints { make in
      make.top.bottom.equalTo(self)
      make.centerX.equalTo(self)
    }
  }
}
