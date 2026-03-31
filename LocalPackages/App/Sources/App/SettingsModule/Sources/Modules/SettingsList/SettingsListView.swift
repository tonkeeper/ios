import TKUIKit
import UIKit

public final class SettingsListView: UIView {
    let navigationBar = TKUINavigationBar()
    let titleView = TKUINavigationBarTitleView()
    let emptyViewContainer = UIView()
    let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        navigationBar.layoutIfNeeded()
        collectionView.contentInset.top = navigationBar.bounds.height
        collectionView.contentInset.bottom = safeAreaInsets.bottom + 16
    }

    func embedEmptyView(_ emptyView: UIView) {
        emptyViewContainer.addSubview(emptyView)
        emptyView.snp.makeConstraints { make in
            make.edges.equalTo(emptyViewContainer)
        }
    }
}

private extension SettingsListView {
    func setup() {
        backgroundColor = .Background.page

        collectionView.backgroundColor = .Background.page
        collectionView.contentInsetAdjustmentBehavior = .never

        navigationBar.scrollView = collectionView
        navigationBar.centerView = titleView

        addSubviews(
            collectionView,
            emptyViewContainer,
            navigationBar
        )

        setupConstraints()
    }

    func setupConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
        }
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        emptyViewContainer.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}
