import UIKit

public final class TKUIHeaderAccentIconButton: TKUIButton<TKUIHeaderButtonIconContentView, TKUIButtonClearBackgroundView> {
  
  public var foregroundColor: UIColor = .Accent.blue {
    didSet {
      setupButtonState()
    }
  }
  
  public convenience init() {
    self.init(
      contentView: TKUIHeaderButtonIconContentView(),
      backgroundView: TKUIButtonClearBackgroundView(),
      contentHorizontalPadding: 0
    )
  }
  
  public override func setupButtonState() {
    switch buttonState {
    case .disabled:
      buttonContentView.setForegroundColor(foregroundColor.withAlphaComponent(0.48))
    case .highlighted:
      buttonContentView.setForegroundColor(foregroundColor.withAlphaComponent(0.48))
    case .normal:
      buttonContentView.setForegroundColor(foregroundColor)
    case .selected:
      break
    }
  }
}
