import UIKit
import TKUIKit

final class StakingOptionsListView: UIView {
    let collectionView = TKUICollectionView(
        frame: .zero,
        collectionViewLayout: UICollectionViewLayout()
    )
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension StakingOptionsListView {
    func setup() {
        backgroundColor = .Background.page
        collectionView.backgroundColor = .Background.page
        collectionView.showsVerticalScrollIndicator = false
        
        addSubview(collectionView)
        
        setupConstraints()
    }
    
    func setupConstraints() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leftAnchor.constraint(equalTo: leftAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.rightAnchor.constraint(equalTo: rightAnchor)
        ])
    }
}
