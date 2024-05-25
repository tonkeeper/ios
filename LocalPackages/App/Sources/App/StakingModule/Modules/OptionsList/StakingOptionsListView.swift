import UIKit
import TKUIKit
import SnapKit
import TKCore

final class StakingOptionsListView: UIView {
  let collectionView = TKUICollectionView(
    frame: .zero,
    collectionViewLayout: UICollectionViewLayout()
  )
  
  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Private methods

private extension StakingOptionsListView {
  func setup() {
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    
    collectionView.fill(in: self)
  }
}
