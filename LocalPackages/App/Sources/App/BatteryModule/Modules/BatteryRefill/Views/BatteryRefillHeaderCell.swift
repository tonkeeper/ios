import UIKit

typealias BatteryRefillHeaderCellRegistration = UICollectionView.CellRegistration<BatteryRefillHeaderCell, BatteryRefillHeaderView.Configuration>

final class BatteryRefillHeaderCell: UICollectionViewCell {
    let view = BatteryRefillHeaderView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        contentView.addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }
    }
}
