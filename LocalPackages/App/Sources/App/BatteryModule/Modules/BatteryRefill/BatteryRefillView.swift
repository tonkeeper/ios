import UIKit
import TKUIKit

final class BatteryRefillView: TKView {
  let navigationBar = TKUINavigationBar()
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: .init())
  
  override func setup() {
    super.setup()
    
    backgroundColor = .Background.page
    
    collectionView.backgroundColor = .Background.page
    collectionView.contentInsetAdjustmentBehavior = .never
    
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

