import UIKit
import TKUIKit

final class StakingConfirmationView: UIView {
    let collectionView = TKUICollectionView(
        frame: .zero,
        collectionViewLayout: UICollectionViewLayout()
    )
    
    lazy var successFlowView: TKSuccessFlowView = {
        let successFlowView = TKSuccessFlowView(
            contentView: sliderView
        )
        return successFlowView
    }()
    
    lazy var sliderView = ConfirmationSliderView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension StakingConfirmationView {
    func setup() {
        backgroundColor = .Background.page
        
        collectionView.backgroundColor = .Background.page
        collectionView.showsVerticalScrollIndicator = false
        addSubview(collectionView)
        
        addSubview(successFlowView)
        setupConstraints()
    }
    
    func setupConstraints() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        successFlowView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leftAnchor.constraint(equalTo: leftAnchor),
            collectionView.bottomAnchor.constraint(equalTo: successFlowView.topAnchor),
            collectionView.rightAnchor.constraint(equalTo: rightAnchor),
            
            successFlowView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            successFlowView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            successFlowView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            successFlowView.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
}
