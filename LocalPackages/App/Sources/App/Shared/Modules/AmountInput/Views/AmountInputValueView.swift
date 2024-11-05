import UIKit
import TKUIKit

final class AmountInputValueView: UIView {
  
  struct Configuration {
    let inputControlConfiguration: AmountInputInputControl.Configuration
    let convertedButtonConfiguration: AmountInputConvertedButton.Configuration
  }
  
  var configuration: Configuration? {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  let inputControl = AmountInputInputControl()
  let convertedButton = AmountInputConvertedButton()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(inputControl)
    addSubview(convertedButton)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    inputControl.snp.makeConstraints { make in
      make.top.equalTo(self)
      make.left.right.equalTo(self).inset(16)
      make.height.equalTo(70)
    }
    convertedButton.snp.makeConstraints { make in
      make.top.equalTo(inputControl.snp.bottom)
      make.left.greaterThanOrEqualTo(self)
      make.right.lessThanOrEqualTo(self)
      make.centerX.equalTo(self)
    }
  }
  
  private func didUpdateConfiguration() {
    guard let configuration else {
      inputControl.configuration = nil
      convertedButton.configuration = nil
      return
    }
    
    inputControl.configuration = configuration.inputControlConfiguration
    convertedButton.configuration = configuration.convertedButtonConfiguration
  }
}
