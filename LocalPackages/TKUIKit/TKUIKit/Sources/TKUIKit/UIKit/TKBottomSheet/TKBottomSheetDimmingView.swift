import UIKit

final class TKBottomSheetDimmingView: UIView {
  private let dismissAlpha: CGFloat
  private let presentAlpha: CGFloat
  
  init(dismissAlpha: CGFloat = 0.0,
       presentAlpha: CGFloat = 0.72) {
    self.dismissAlpha = dismissAlpha
    self.presentAlpha = presentAlpha
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func prepareForPresentationTransition() {
    alpha = dismissAlpha
  }
  
  func performPresentationTransition() {
    alpha = presentAlpha
  }
  
  func prepareForDimissalTransition() {}
  
  func performDismissalTransition() {
    alpha = dismissAlpha
  }
}

private extension TKBottomSheetDimmingView {
  func setup() {
    backgroundColor = .Background.overlayStrong
  }
}
