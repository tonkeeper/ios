import TKUIKit
import UIKit

final class BrowserConnectedView: UIView {
    let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
    let emptyViewContainer = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func embedEmptyView(_ emptyView: UIView) {
        emptyViewContainer.addSubview(emptyView)
        emptyView.snp.makeConstraints { make in
            make.edges.equalTo(emptyViewContainer)
        }
    }

    func didUpdateTopInset() {
        emptyViewContainer.snp.remakeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}

private extension BrowserConnectedView {
    func setup() {
        backgroundColor = .Background.page
        collectionView.backgroundColor = .Background.page
        collectionView.contentInsetAdjustmentBehavior = .never

        addSubview(collectionView)
        addSubview(emptyViewContainer)

        setupConstraints()
    }

    func setupConstraints() {
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        emptyViewContainer.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}
