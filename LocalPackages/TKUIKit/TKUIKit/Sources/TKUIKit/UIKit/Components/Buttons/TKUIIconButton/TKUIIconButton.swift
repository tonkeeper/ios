import UIKit

public final class TKUIIconButton: TKUIButton<TKUIIconButtonContentView, TKUIButtonClearBackgroundView> {
    
  public convenience init() {
    self.init(
      contentView: TKUIIconButtonContentView(),
      backgroundView: TKUIButtonClearBackgroundView(),
      contentHorizontalPadding: 0
    )
  }
  
  public override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 80)
  }
  
  public override func setupButtonState() {
    let iconColor: UIColor
    let titleColor: UIColor
    switch buttonState {
    case .disabled:
      iconColor = .Icon.primary.withAlphaComponent(0.32)
      titleColor = .Text.secondary.withAlphaComponent(0.32)
    case .highlighted:
      iconColor = .Icon.primary.withAlphaComponent(0.48)
      titleColor = .Text.secondary.withAlphaComponent(0.48)
    case .normal:
      iconColor = .Icon.primary
      titleColor = .Text.secondary
    case .selected:
      iconColor = .Icon.primary
      titleColor = .Text.secondary
    }
    
    buttonContentView.setIconColor(iconColor)
    buttonContentView.setTitleColor(titleColor)
  }
}
