import UIKit

final class TKTextFieldBackgroundView: UIView {

  var highlightBorder = true
  
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
    
    if highlightBorder { layer.borderWidth = 1.5 }
    layer.cornerRadius = 16
  }
  
  func didUpdateState() {
    backgroundColor = textFieldState.backgroundColor
    if highlightBorder { layer.borderColor = textFieldState.borderColor.cgColor }
  }
}
