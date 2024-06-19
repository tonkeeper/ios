import UIKit
import TKUIKit
import SnapKit

final class PasscodeView: UIView {
  let keyboardView = TKKeyboardView()
  let topContainer = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension PasscodeView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(topContainer)
    addSubview(keyboardView)
    
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
