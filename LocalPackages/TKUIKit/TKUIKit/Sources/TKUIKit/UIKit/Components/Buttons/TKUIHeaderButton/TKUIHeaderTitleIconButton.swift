import UIKit

public final class TKUIHeaderTitleIconButton: TKUIButton<TKUIButtonTitleIconContentView, TKUIButtonDefaultBackgroundView> {
  public convenience init() {
    self.init(
      contentView: TKUIButtonTitleIconContentView(textStyle: .label2, foregroundColor: .Button.primaryForeground),
      backgroundView: TKUIButtonDefaultBackgroundView(cornerRadius: 16),
      contentHorizontalPadding: 12
    )
  }
  
  public override var intrinsicContentSize: CGSize {
    CGSize(width: contentView.intrinsicContentSize.width + padding.left + padding.right, height: 32 + padding.top + padding.bottom)
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
