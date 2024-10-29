import UIKit
import TKUIKit

final class StakingListView: TKView {
  let navigationBar = TKUINavigationBar()
  let titleView = TKUINavigationBarTitleView()
  let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
  
  override func setup() {
    super.setup()
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    
    navigationBar.centerView = titleView
    
    addSubview(collectionView)
    addSubview(navigationBar)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    navigationBar.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
    }
  }
}
