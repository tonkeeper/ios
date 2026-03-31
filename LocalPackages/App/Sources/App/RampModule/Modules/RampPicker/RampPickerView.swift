import SnapKit
import TKLocalize
import TKUIKit
import UIKit

final class RampPickerView: TKView {
    let navigationBar = TKUINavigationBar()
    let titleView = TKUINavigationBarTitleView()
    let searchStackView = UIStackView()
    let searchBar = BrowserSearchBar()
    let zeroSearchLabel = UILabel()

    var isSearchBarHidden: Bool = false {
        didSet {
            guard isSearchBarHidden != oldValue else { return }
            searchStackView.isHidden = isSearchBarHidden
            updateCollectionViewConstraints()
        }
    }

    let collectionView = TKUICollectionView(
        frame: .zero,
        collectionViewLayout: UICollectionViewLayout()
    )

    override func layoutSubviews() {
        super.layoutSubviews()

        navigationBar.layoutIfNeeded()
        collectionView.contentInset.bottom = safeAreaInsets.bottom + 16
    }

    override func setup() {
        super.setup()

        backgroundColor = .Background.page
        collectionView.backgroundColor = .Background.page
        collectionView.contentInsetAdjustmentBehavior = .never

        navigationBar.scrollView = collectionView
        navigationBar.centerView = titleView

        searchBar.backgroundColor = .Background.page
        searchBar.isBlur = false
        searchBar.placeholder = TKLocales.Ramp.RampPicker.Search.placeholder
        searchBar.isCancelButtonOnEdit = true
        searchBar.padding = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        zeroSearchLabel.isHidden = true
        zeroSearchLabel.attributedText = TKLocales.Ramp.RampPicker.Search.zeroTitle.withTextStyle(
            .body2,
            color: .Text.tertiary,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )

        searchStackView.axis = .vertical
        searchStackView.spacing = 32

        addSubview(collectionView)
        addSubview(searchStackView)
        addSubview(navigationBar)

        searchStackView.addArrangedSubview(searchBar)
        searchStackView.addArrangedSubview(zeroSearchLabel)

        setupConstraints()
    }

    func setupConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(self)
        }

        searchStackView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalTo(self)
        }

        searchBar.snp.makeConstraints { make in
            make.height.equalTo(48)
        }

        updateCollectionViewConstraints()
    }

    private func updateCollectionViewConstraints() {
        collectionView.snp.remakeConstraints { make in
            make.leading.trailing.bottom.equalTo(self)
            if isSearchBarHidden {
                make.top.equalTo(navigationBar.snp.bottom)
            } else {
                make.top.equalTo(searchStackView.snp.bottom).offset(16)
            }
        }
    }
}
