import UIKit

public final class TKUICollectionView: UICollectionView {
    override public init(
        frame: CGRect,
        collectionViewLayout layout: UICollectionViewLayout
    ) {
        super.init(frame: frame, collectionViewLayout: layout)
        canCancelContentTouches = true
        showsVerticalScrollIndicator = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func touchesShouldCancel(in view: UIView) -> Bool {
        guard !(view is UIControl) else { return true }
        return super.touchesShouldCancel(in: view)
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        self.endEditing(true)
    }
}
