import UIKit
import TKUIKit
import SnapKit

public final class BuySellView: UIView {
    let amountInputContainer = UIView()
    
    let methodsCollectionView = UICollectionView(
        frame: .init(),
        collectionViewLayout: UICollectionViewLayout()
    )
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.page
        
        addSubview(amountInputContainer)
        
        methodsCollectionView.isScrollEnabled = false
        methodsCollectionView.backgroundColor = .Background.page
        addSubview(methodsCollectionView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func embedAmountInputView(_ view: UIView) {
        amountInputContainer.addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalTo(amountInputContainer)
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        amountInputContainer.frame = .init(
            x: 0,
            y: 0,
            width: bounds.width,
            height: .amountInputContainerHeight
        )
        
        let methodsCollectionViewMinY = .amountInputContainerHeight + 16.0
        let methodsCollectionViewHeight = bounds.height - methodsCollectionViewMinY
        
        methodsCollectionView.frame = .init(
            x: 0,
            y: methodsCollectionViewMinY,
            width: bounds.width,
            height: methodsCollectionViewHeight
        )
    }
}

private extension CGFloat {
    static let amountInputContainerHeight = 178.0
}
