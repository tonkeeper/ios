import UIKit
import TKUIKit

public final class WalletContainerWalletButton: TKUIButton<TKUIButtonTitleIconContentView, TKUIButtonDefaultBackgroundView> {
  
  struct Appearance {
    let backgroundColor: UIColor
    let foregroundColor: UIColor
  }
  
  var appearance = Appearance(backgroundColor: .black, foregroundColor: .white) {
    didSet {
      setupAppearance()
    }
  }

  public init() {
    super.init(
      contentView: TKUIButtonTitleIconContentView(
        textStyle: .label2,
        foregroundColor: appearance.foregroundColor),
      backgroundView: TKUIButtonDefaultBackgroundView(cornerRadius: 20),
      contentHorizontalPadding: 12
    )
    setupAppearance()
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 40)
  }
  
  public override func setupButtonState() {
    switch buttonState {
    case .normal:
      alpha = 1
    case .highlighted:
      alpha = 0.48
    case .disabled:
      alpha = 0.48
    }
  }
  
  private func setupAppearance() {
    backgroundView.setBackgroundColor(appearance.backgroundColor)
    buttonContentView.setForegroundColor(appearance.foregroundColor)
  }
}
