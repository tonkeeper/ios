import UIKit
import TKUIKit
import SnapKit

public final class PasscodeView: UIView, ConfigurableView {
  let keyboardView = TKKeyboardView(configuration: .passcodeConfiguration(biometry: nil))
  let topContainer = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Model {
    let keyboardConfiguration: TKKeyboardView.Configuration
  }
  
  public func configure(model: Model) {
    keyboardView.configuration = model.keyboardConfiguration
  }
}

private extension PasscodeView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(keyboardView)
    addSubview(topContainer)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    keyboardView.snp.makeConstraints { make in
      make.bottom.equalTo(safeAreaLayoutGuide).inset(16)
      make.left.right.equalTo(self).inset(16)
    }
    
    topContainer.snp.makeConstraints { make in
      make.top.equalTo(safeAreaLayoutGuide)
      make.left.right.equalTo(self)
      make.bottom.equalTo(keyboardView.snp.top)
    }
  }
}
