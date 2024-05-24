import UIKit
import TKUIKit

final class SwapTokenPickerView: UIView {
  let collectionView = TKUICollectionView(frame: .zero,
                                          collectionViewLayout: UICollectionViewLayout())
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension SwapTokenPickerView {
  func setup() {
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    
    addSubview(collectionView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: topAnchor),
      collectionView.leftAnchor.constraint(equalTo: leftAnchor),
      collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
      collectionView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
