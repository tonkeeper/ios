import UIKit

public final class TKUIHeaderIconButton: TKUIButton<TKUIHeaderButtonIconContentView, TKUIButtonDefaultBackgroundView> {
  public convenience init() {
    self.init(
      contentView: TKUIHeaderButtonIconContentView(), 
      backgroundView: TKUIButtonDefaultBackgroundView(cornerRadius: 16),
      contentHorizontalPadding: 8
    )
  }
  
  public override var intrinsicContentSize: CGSize {
    CGSize(width: 32 + padding.left + padding.right, height: 32 + padding.top + padding.bottom)
  }
  
  public override func setupButtonState() {
    switch buttonState {
    case .disabled:
      backgroundView.setBackgroundColor(.Button.secondaryBackground.withAlphaComponent(0.48))
      buttonContentView.setForegroundColor(.Button.secondaryForeground.withAlphaComponent(0.48))
    case .highlighted:
      backgroundView.setBackgroundColor(.Button.secondaryBackground.withAlphaComponent(0.48))
      buttonContentView.setForegroundColor(.Button.secondaryForeground.withAlphaComponent(0.48))
    case .normal:
      backgroundView.setBackgroundColor(.Button.secondaryBackground)
      buttonContentView.setForegroundColor(.Button.secondaryForeground)
    case .selected:
      break
    }
  }
}
