import UIKit
import TKUIKit

// MARK: - SwapTokenButton

final class SwapTokenButton: TKUIButton<IconButttonContentView, TKUIButtonDefaultBackgroundView> {
  
  init() {
    super.init(
      contentView: IconButttonContentView(),
      backgroundView: TKUIButtonDefaultBackgroundView(cornerRadius: 18),
      contentHorizontalPadding: 0
    )
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func setupButtonState() {
    switch buttonState {
    case .normal:
      backgroundView.setBackgroundColor(.Button.tertiaryBackground)
    case .highlighted:
      backgroundView.setBackgroundColor(.Button.tertiaryBackgroundHighlighted)
    case .disabled:
      backgroundView.setBackgroundColor(.Button.tertiaryBackground.withAlphaComponent(0.48))
    case .selected:
      backgroundView.setBackgroundColor(.Button.tertiaryBackground)
    }
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return contentView.sizeThatFits(size)
  }
  
  private func setup () {
    backgroundView.backgroundColor = .Button.tertiaryBackground
  }
}
