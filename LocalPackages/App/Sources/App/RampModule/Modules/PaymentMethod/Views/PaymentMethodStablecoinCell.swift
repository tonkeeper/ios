import TKUIKit
import UIKit

final class PaymentMethodStablecoinCell: TKCollectionViewListCell {
    struct Configuration: Hashable {
        let contentConfiguration: PaymentMethodStablecoinContentView.Configuration
    }

    var configuration = Configuration(contentConfiguration: .init(image: nil, title: "", networkIconURLs: [])) {
        didSet {
            stablecoinContentView.configuration = configuration.contentConfiguration
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    private let stablecoinContentView = PaymentMethodStablecoinContentView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .Background.content

        let highlightView = UIView()
        highlightView.backgroundColor = .Background.highlighted
        self.highlightView = highlightView

        layer.cornerRadius = 16
        setContentView(stablecoinContentView)
        listCellContentViewPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
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
        stablecoinContentView.prepareForReuse()
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
