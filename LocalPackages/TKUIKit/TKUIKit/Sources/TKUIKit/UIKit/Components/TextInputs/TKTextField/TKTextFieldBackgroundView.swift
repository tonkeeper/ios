import UIKit

final class TKTextFieldBackgroundView: UIView {
  
  var textFieldState: TKTextFieldState = .inactive {
    didSet {
      didUpdateState()
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension TKTextFieldBackgroundView {
  func setup() {
    didUpdateState()
    
    layer.borderWidth = 1.5
    layer.cornerRadius = 16
  }
  
  func didUpdateState() {
    backgroundColor = textFieldState.backgroundColor
    layer.borderColor = textFieldState.borderColor.cgColor
  }
}
