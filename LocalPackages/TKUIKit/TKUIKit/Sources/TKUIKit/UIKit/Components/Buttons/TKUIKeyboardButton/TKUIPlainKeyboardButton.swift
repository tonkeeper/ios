import UIKit

public final class TKUIPlainKeyboardButton: TKUIButton<TKUIKeyboardButtonContentView, TKUIKeyboardButtonPlainBackgroundView> {
  
  public init() {
    super.init(contentView: TKUIKeyboardButtonContentView(textStyle: .num1),
               backgroundView: TKUIKeyboardButtonPlainBackgroundView())
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override var intrinsicContentSize: CGSize {
    CGSize(width: 72, height: 72)
  }
  
  public override func setupButtonState() {
    backgroundView.state = buttonState
  }
}
