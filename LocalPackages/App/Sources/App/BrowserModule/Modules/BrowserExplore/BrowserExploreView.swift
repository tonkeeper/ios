import TKUIKit
import UIKit

final class BrowserExploreView: UIView {
    var topInset: CGFloat = 0 {
        didSet {
            topLayoutGuide.snp.remakeConstraints { make in
                make.left.right.equalTo(self)
                make.top.equalTo(self)
                make.height.equalTo(topInset)
            }
        }
    }

    let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
    let topLayoutGuide = UILayoutGuide()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension BrowserExploreView {
    func setup() {
        backgroundColor = .Background.page
        collectionView.backgroundColor = .Background.page

        if !UIApplication.useSystemBarsAppearance {
            collectionView.contentInsetAdjustmentBehavior = .never
        }

        addSubview(collectionView)

        addLayoutGuide(topLayoutGuide)

        setupConstraints()
    }

    func setupConstraints() {
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        topLayoutGuide.snp.makeConstraints { make in
            make.left.right.equalTo(self)
            make.top.equalTo(self)
            make.height.equalTo(topInset)
        }
    }
}
