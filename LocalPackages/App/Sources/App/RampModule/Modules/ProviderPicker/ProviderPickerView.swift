import SnapKit
import TKUIKit
import UIKit

final class ProviderPickerView: TKView {
    let collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, _ in nil }
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()

    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.contentInset.bottom = safeAreaInsets.bottom + 16
    }

    override func setup() {
        super.setup()

        backgroundColor = .Background.page

        collectionView.backgroundColor = .Background.page
        collectionView.contentInsetAdjustmentBehavior = .never

        addSubview(collectionView)

        setupConstraints()
    }

    func setupConstraints() {
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}
