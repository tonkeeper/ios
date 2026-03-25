import SnapKit
import TKUIKit
import UIKit

final class WalletBalanceView: UIView {
    let headerView = BalanceHeaderView()
    let refreshControl = UIRefreshControl()

    let collectionView = TKUICollectionView(
        frame: .zero,
        collectionViewLayout: UICollectionViewLayout()
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension WalletBalanceView {
    func setup() {
        backgroundColor = .Background.page
        collectionView.backgroundColor = .Background.page
        collectionView.contentInset.bottom = 16
        collectionView.refreshControl = refreshControl

        addSubview(collectionView)

        setupConstraints()
    }

    func setupConstraints() {
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}
