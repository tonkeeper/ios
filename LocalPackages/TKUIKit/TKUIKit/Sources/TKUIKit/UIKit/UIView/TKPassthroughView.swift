import UIKit

open class TKPassthroughView: UIView {
  public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let view = super.hitTest(point, with: event)
    return view === self ? nil : view
  }
}

open class TKPassthroughStackView: UIStackView {
  public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let view = super.hitTest(point, with: event)
    return (view is UIControl && view?.isUserInteractionEnabled == true) ? view : nil
  }
}
