import UIKit

public final class TKSecureBlurView: UIView {
  private var blurView: UIVisualEffectView?
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setupBlurView()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
      setupBlurView()
    }
  }
  
  private func setupBlurView() {
    blurView?.removeFromSuperview()
    let blurView = createBlurView()
    addSubview(blurView)
    blurView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    self.blurView = blurView
  }
  
  private func createBlurView() -> UIVisualEffectView {
    let style: UIBlurEffect.Style
    switch traitCollection.userInterfaceStyle {
    case .light:
      style = .light
    case .dark:
      style = .light
    default:
      style = .light
    }
    let blurEffect = UIBlurEffect(style: style)
    let blurView = UIVisualEffectView(effect: blurEffect)
    return blurView
  }
}
