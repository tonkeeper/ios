import TKUIKit
import UIKit

public final class WalletBalanceMoreAssetsListCell: TKCollectionViewListCell {
    private let moreAssetsContentView = WalletBalanceMoreAssetsContainerView()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.content

        let highlightView = UIView()
        highlightView.backgroundColor = .Background.highlighted
        self.highlightView = highlightView

        layer.cornerRadius = 16
        listCellContentViewPadding = .zero
        setContentView(moreAssetsContentView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(previewAvatars: [AssetAvatarViewImageSource]) {
        moreAssetsContentView.configure(previewAvatars: previewAvatars)
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    override public func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        attributes.frame.size.height = Layout.rowHeight
        return attributes
    }

    override public func didUpdateCellOrderInSection() {
        super.didUpdateCellOrderInSection()
        updateCornerRadius()
    }

    private enum Layout {
        static let rowHeight: CGFloat = 56
    }

    private func updateCornerRadius() {
        let maskedCorners: CACornerMask
        let isMasksToBounds: Bool
        switch (isFirst, isLast) {
        case (true, true):
            maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            isMasksToBounds = true
        case (false, true):
            maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            isMasksToBounds = true
        case (true, false):
            maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            isMasksToBounds = true
        case (false, false):
            maskedCorners = []
            isMasksToBounds = false
        }
        layer.maskedCorners = maskedCorners
        layer.masksToBounds = isMasksToBounds
    }
}
