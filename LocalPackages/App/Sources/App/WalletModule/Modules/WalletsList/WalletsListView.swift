import UIKit
import TKUIKit

final class WalletsListView: UIView, ConfigurableView {
  
  let collectionView = UICollectionView(frame: .zero,
                                        collectionViewLayout: UICollectionViewLayout())
  
  let footerView = WalletsListFooterView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let footerViewModel: WalletsListFooterView.Model
  }
  
  func configure(model: Model) {
    footerView.configure(model: model.footerViewModel)
  }
}

private extension WalletsListView {
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
