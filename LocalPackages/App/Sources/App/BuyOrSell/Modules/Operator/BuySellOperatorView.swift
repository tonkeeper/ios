import UIKit
import TKUIKit
import SnapKit

public final class BuySellOperatorView: UIView {
    let navigationBarView: TKNavigationBarContainer = {
        let navigationBarView = TKNavigationBarContainer(barHeight: 48)
        return navigationBarView
    }()
    
    let backButton: TKUIHeaderIconButton = {
        let v = TKUIHeaderIconButton()
        v.configure(
            model: TKUIHeaderButtonIconContentView.Model(
                image: .TKUIKit.Icons.Size16.chevronLeft
            )
        )
        v.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        return v
    }()
    
    let closeButton: TKUIHeaderIconButton = {
        let v = TKUIHeaderIconButton()
        v.configure(
            model: TKUIHeaderButtonIconContentView.Model(
                image: .TKUIKit.Icons.Size16.close
            )
        )
        v.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        return v
    }()

    let titleView: TKTitleDescriptionView = {
        let v = TKTitleDescriptionView(size: .medium)
        v.configure(
            model: .init(
                title: "Operator",
                bottomDescription: "Credit Card"
            )
        )
        return v
    }()
        
    let collectionView = UICollectionView(
        frame: .init(),
        collectionViewLayout: UICollectionViewLayout()
    )
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.page
                
        collectionView.backgroundColor = .Background.page
        addSubview(collectionView)
        
        navigationBarView.barViews = [backButton, titleView, closeButton]
        navigationBarView.barPadding = .init(top: 4, left: 16, bottom: 8, right: 16)
        navigationBarView.contentPadding = .zero
        navigationBarView.scrollView = collectionView
        addSubview(navigationBarView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        navigationBarView.frame = .init(x: 0, y: 0, width: bounds.width, height: navigationBarView.additionalInset)
        
        collectionView.frame = bounds
        collectionView.contentInset.top = navigationBarView.additionalInset
        collectionView.verticalScrollIndicatorInsets.top = navigationBarView.additionalInset
    }
}
