import UIKit

public final class TKReusableContainerView: UICollectionReusableView, ReusableView {
    private var contentView: UIView?

    public func setContentView(_ contentView: UIView?) {
        if let current = self.contentView, current !== contentView, current.superview === self {
            current.removeFromSuperview()
        }
        self.contentView = contentView
        guard let contentView else { return }
        addSubview(contentView)

        contentView.snp.remakeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}
