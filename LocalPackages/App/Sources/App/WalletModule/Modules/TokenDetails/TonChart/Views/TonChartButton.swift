import UIKit
import TKUIKit

final class TonChartButton: TKButton {
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColors = [.selected: TKUIActionButtonCategory.secondary.backgroundColor,
                        .normal: .clear]
    foregroundColors = [
      .normal: .Button.primaryForeground,
      .highlighted: .Button.primaryForeground.withAlphaComponent(0.48)
    ]
    textStyle = TKUIActionButtonSize.small.textStyle
    cornerRadius = TKUIActionButtonSize.small.cornerRadius
    contentPadding = TKUIActionButtonSize.small.padding
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
