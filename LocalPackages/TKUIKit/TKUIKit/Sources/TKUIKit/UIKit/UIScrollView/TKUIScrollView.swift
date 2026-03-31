import UIKit

public final class TKUIScrollView: UIScrollView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        canCancelContentTouches = true
        showsVerticalScrollIndicator = false
        alwaysBounceVertical = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func touchesShouldCancel(in view: UIView) -> Bool {
        guard !(view is UIControl) else { return true }
        return super.touchesShouldCancel(in: view)
    }
}
