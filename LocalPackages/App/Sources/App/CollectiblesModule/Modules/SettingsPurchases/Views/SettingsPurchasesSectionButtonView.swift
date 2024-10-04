import UIKit
import TKUIKit

final class SettingsPurchasesSectionButtonView: UICollectionReusableView, ConfigurableView {
  struct Model {
    let buttonConfiguration: TKButton.Configuration
  }
  
  func configure(model: Model) {
    button.configuration = model.buttonConfiguration
  }
  
  let button = TKButton()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(button)
    button.snp.makeConstraints { make in
      make.top.equalTo(self).offset(16)
      make.left.greaterThanOrEqualTo(self).offset(16)
      make.right.lessThanOrEqualTo(self).offset(-16)
      make.centerX.equalTo(self)
      make.bottom.equalTo(self)
    }
  }
}
