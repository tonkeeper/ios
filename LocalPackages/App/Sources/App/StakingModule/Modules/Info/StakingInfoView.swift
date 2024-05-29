import UIKit
import TKUIKit

final class StakingInfoView: UIView {
    var continueButtonBottomConstraint: NSLayoutConstraint?
    
    let continueButton = TKButton()

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

private extension StakingInfoView {
    func setup() {
        backgroundColor = .Background.page
        collectionView.backgroundColor = .Background.page
        collectionView.showsVerticalScrollIndicator = false
        
        addSubview(collectionView)
        addSubview(continueButton)
        
        setupConstraints()
    }
    
    func setupConstraints() {
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
                
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leftAnchor.constraint(equalTo: leftAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.rightAnchor.constraint(equalTo: rightAnchor),
            
            continueButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            continueButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            continueButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
    }
}
