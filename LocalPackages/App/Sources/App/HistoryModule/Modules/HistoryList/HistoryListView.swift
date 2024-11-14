import UIKit
import TKUIKit

final class HistoryListView: UIView {

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

private extension HistoryListView {
  func setup() {

    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    collectionView.showsVerticalScrollIndicator = false
//    collectionView.contentInsetAdjustmentBehavior = .never

    addSubview(collectionView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
