import TKUIKit
import UIKit

final class PaymentMethodAllItemsCell: TKCollectionViewListCell {
    struct Configuration: Hashable {
        let contentConfiguration: PaymentMethodAllItemsContentView.Configuration
    }

    var configuration = Configuration(contentConfiguration: .empty) {
        didSet {
            allItemsContentView.configuration = configuration.contentConfiguration
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    private let allItemsContentView = PaymentMethodAllItemsContentView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .Background.content

        let highlightView = UIView()
        highlightView.backgroundColor = .Background.highlighted
        self.highlightView = highlightView

        layer.cornerRadius = 16
        setContentView(allItemsContentView)
        listCellContentViewPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        defaultAccessoryViews = [TKListItemAccessory.chevron.view]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didUpdateCellOrderInSection() {
        super.didUpdateCellOrderInSection()
        updateCornerRadius()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        allItemsContentView.prepareForReuse()
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
