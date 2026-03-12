import TKLocalize
import TKUIKit
import UIKit

final class TokenPickerView: UIView {
    let searchStackView = UIStackView()
    let searchBar = BrowserSearchBar()
    let zeroSearchLabel = UILabel()
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

private extension TokenPickerView {
    func setup() {
        backgroundColor = .Background.page
        collectionView.backgroundColor = .Background.page

        searchBar.backgroundColor = .Background.page
        searchBar.isBlur = false
        searchBar.placeholder = TKLocales.TokensPicker.Search.placeholder
        searchBar.isCancelButtonOnEdit = true
        searchBar.padding = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        zeroSearchLabel.isHidden = true
        zeroSearchLabel.attributedText = TKLocales.TokensPicker.Search.zeroTitle.withTextStyle(
            .body2,
            color: .Text.tertiary,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )

        searchStackView.axis = .vertical
        searchStackView.spacing = 32

        addSubview(searchStackView)
        addSubview(collectionView)

        searchStackView.addArrangedSubview(searchBar)
        searchStackView.addArrangedSubview(zeroSearchLabel)

        setupConstraints()
    }

    func setupConstraints() {
        searchStackView.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
        }

        searchBar.snp.makeConstraints { make in
            make.height.equalTo(48)
        }

        collectionView.snp.remakeConstraints { make in
            make.top.equalTo(searchStackView.snp.bottom).offset(16)
            make.left.right.bottom.equalTo(self)
        }
    }
}
