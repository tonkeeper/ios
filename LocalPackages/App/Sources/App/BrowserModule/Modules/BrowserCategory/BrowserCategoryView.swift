import TKLocalize
import TKUIKit
import UIKit

final class BrowserCategoryView: UIView {
    let navigationBar = TKUINavigationBar()
    let titleView = TKUINavigationBarTitleView()
    let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
    let searchBar = BrowserSearchBar()
    let blurView = TKBlurView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCollectionViewInsets()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateCollectionViewInsets()
    }
}

private extension BrowserCategoryView {
    func setup() {
        backgroundColor = .Background.page

        collectionView.backgroundColor = .Background.page
        collectionView.contentInsetAdjustmentBehavior = .never

        navigationBar.scrollView = collectionView
        navigationBar.centerView = titleView

        searchBar.blurView.isHidden = true
        searchBar.textField.isUserInteractionEnabled = false
        searchBar.placeholder = TKLocales.Browser.SearchField.placeholder

        addSubview(collectionView)
        addSubview(blurView)
        addSubview(searchBar)
        addSubview(navigationBar)

        setupConstraints()
    }

    func setupConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
        }
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        searchBar.snp.makeConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide)
            make.left.right.equalTo(self)
        }

        blurView.snp.makeConstraints { make in
            make.bottom.left.right.equalTo(self)
            make.top.equalTo(searchBar)
        }
    }

    func updateCollectionViewInsets() {
        navigationBar.layoutIfNeeded()
        searchBar.layoutIfNeeded()
        collectionView.contentInset.top = navigationBar.bounds.height
        collectionView.contentInset.bottom = searchBar.bounds.height + safeAreaInsets.bottom
    }
}
