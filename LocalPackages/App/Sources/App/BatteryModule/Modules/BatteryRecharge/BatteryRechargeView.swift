import UIKit
import TKUIKit

final class BatteryRechargeView: TKView {
  let navigationBar = TKUINavigationBar()
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: .init())

  public override func layoutSubviews() {
    super.layoutSubviews()
   
    navigationBar.layoutIfNeeded()
    collectionView.contentInset.top = navigationBar.bounds.height
    collectionView.contentInset.bottom = safeAreaInsets.bottom + 16
  }

  override func setup() {
    super.setup()
    
    backgroundColor = .Background.page
    
    collectionView.backgroundColor = .Background.page
    collectionView.contentInsetAdjustmentBehavior = .never
    
    navigationBar.scrollView = collectionView
    
    addSubview(collectionView)
    addSubview(navigationBar)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    navigationBar.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
    }
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}

