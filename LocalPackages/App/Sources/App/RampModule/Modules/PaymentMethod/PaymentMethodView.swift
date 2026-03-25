import TKUIKit
import UIKit

final class PaymentMethodView: TKView {
    let navigationBar = TKUINavigationBar()
    let titleView = TKUINavigationBarTitleView()
    let collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, _ in nil }
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()

    override func layoutSubviews() {
        super.layoutSubviews()
        navigationBar.layoutIfNeeded()
        collectionView.contentInset.top = navigationBar.bounds.height
        collectionView.contentInset.bottom = safeAreaInsets.bottom + 16
    }

    override func setup() {
        super.setup()

        backgroundColor = .Background.page

        collectionView.backgroundColor = .Background.page
        collectionView.contentInsetAdjustmentBehavior = .never

        navigationBar.scrollView = collectionView
        navigationBar.centerView = titleView

        addSubview(collectionView)
        addSubview(navigationBar)

        setupConstraints()
    }

    func setupConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(self)
        }
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}
