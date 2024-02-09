import UIKit
import TKUIKit

final class TonChartButton: TKUIButton<TKUIButtonTitleIconContentView, TKUIButtonDefaultBackgroundView> {
  
  override var isSelected: Bool {
    didSet {
      guard isSelected != oldValue else { return }
      didUpdateIsSelected()
    }
  }
  
  init() {
    super.init(
      contentView: TKUIButtonTitleIconContentView(
        textStyle: TKUIActionButtonSize.small.textStyle,
        foregroundColor: TKUIActionButtonCategory.secondary.titleColor),
      backgroundView: TKUIButtonDefaultBackgroundView(cornerRadius: TKUIActionButtonSize.small.cornerRadius),
      contentHorizontalPadding: TKUIActionButtonSize.small.padding.left
    )
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override var intrinsicContentSize: CGSize {
    CGSize(
      width: UIView.noIntrinsicMetric,
      height: TKUIActionButtonSize.small.height
    )
  }
  
  public override func setupButtonState() {
    let category = TKUIActionButtonCategory.secondary
    switch buttonState {
    case .disabled:
      buttonContentView.setForegroundColor(category.disabledTitleColor)
    case .highlighted:
      buttonContentView.setForegroundColor(category.titleColor)
    case .normal:
      buttonContentView.setForegroundColor(category.titleColor)
    }
  }
  
  private func didUpdateIsSelected() {
    let color = isSelected ? TKUIActionButtonCategory.secondary.backgroundColor : .clear
    backgroundView.setBackgroundColor(color)
  }
}
