import UIKit
import TKUIKit

final class StakingListView: TKView {
  let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
  
  override func setup() {
    super.setup()
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    
    addSubview(collectionView)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
