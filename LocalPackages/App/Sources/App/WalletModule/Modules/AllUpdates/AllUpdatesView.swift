import TKUIKit
import UIKit

final class AllUpdatesView: UIView {
    let navigationBar = TKUINavigationBar()
    let titleView = TKUINavigationBarTitleView()

    let collectionView: UICollectionView = {
        let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: .init())
        collectionView.backgroundColor = .Background.page
        return collectionView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .Background.page

        navigationBar.leftViews = [titleView]

        addSubview(navigationBar)
        addSubview(collectionView)

        setupConstraints()
    }

    private func setupConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.left.right.bottom.equalTo(self)
        }
    }
}
