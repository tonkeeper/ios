import UIKit
import TKUIKit

public final class CurrencyPickerView: UIView {
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension CurrencyPickerView {
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
      collectionView.rightAnchor.constraint(equalTo: rightAnchor),
      collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }
}
