import UIKit
import TKUIKit

final class TonChartButton: TKButton {
  
  init() {
    var configuration = TKButton.Configuration.actionButtonConfiguration(
      category: .secondary,
      size: .small
    )
    configuration.backgroundColors = [.normal: .clear,
                                      .selected: TKActionButtonCategory.secondary.backgroundColor]
    configuration.textColor = .Button.primaryForeground
    configuration.contentAlpha = [.normal: 1,
                                  .highlighted: 0.48]
    super.init(configuration: configuration)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
