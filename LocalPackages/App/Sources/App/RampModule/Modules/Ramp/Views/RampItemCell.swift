import TKUIKit
import UIKit

final class RampItemCell: TKCollectionViewListCell {
    struct Configuration: Hashable {
        var listItemContentViewConfiguration: RampItemContentView.Configuration

        static var `default`: Configuration {
            Configuration(listItemContentViewConfiguration: .default)
        }

        init(listItemContentViewConfiguration: RampItemContentView.Configuration) {
            self.listItemContentViewConfiguration = listItemContentViewConfiguration
        }
    }

    let listItemContentView = RampItemContentView()

    var configuration = Configuration.default {
        didSet {
            didUpdateConfiguration()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.content

        let highlightView = UIView()
        highlightView.backgroundColor = .Background.highlighted
        self.highlightView = highlightView

        layer.cornerRadius = 16

        setContentView(listItemContentView)
        listCellContentViewPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        didUpdateConfiguration()
    }

    override func didUpdateCellOrderInSection() {
        super.didUpdateCellOrderInSection()
        updateCornerRadius()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        listItemContentView.prepareForReuse()
    }

    private func didUpdateConfiguration() {
        listItemContentView.configuration = configuration.listItemContentViewConfiguration
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

typealias RampItemCellRegistration = UICollectionView.CellRegistration<RampItemCell, RampItemCell.Configuration>

extension RampItemCellRegistration {
    static func registration(collectionView: UICollectionView) -> RampItemCellRegistration {
        RampItemCellRegistration { cell, _, configuration in
            cell.configuration = configuration
            cell.isFirstInSection = { ip in ip.item == 0 }
            cell.isLastInSection = { [weak collectionView] ip in
                guard let collectionView = collectionView else { return false }
                return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
            }
        }
    }
}
