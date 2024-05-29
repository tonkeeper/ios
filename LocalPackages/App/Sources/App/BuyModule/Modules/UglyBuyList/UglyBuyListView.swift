import UIKit
import TKUIKit

final class UglyBuyListView: UIView {
  
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: .init())

  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override func layoutSubviews() {
    super.layoutSubviews()
    collectionView.frame = bounds
  }
}

// MARK: - Private

private extension UglyBuyListView {
  func setup() {
    collectionView.backgroundColor = .Background.page
    addSubview(collectionView)
  }
}
