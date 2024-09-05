import UIKit
import TKUIKit
import SnapKit

final class WalletBalanceView: UIView, ConfigurableView {
  
  let headerView = BalanceHeaderView()
  
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
  
  struct Model {
//    let headerViewModel: WalletBalanceHeaderView.Model
  }
  
  func configure(model: Model) {
//    headerView.configure(model: model.headerViewModel)
  }
}

private extension WalletBalanceView {
  func setup() {
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    collectionView.contentInset.bottom = 16
    
//    addSubview(headerView)
    addSubview(collectionView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
//    headerView.snp.makeConstraints { make in
//      make.left.right.equalTo(self)
//      make.top.equalTo(safeAreaLayoutGuide)
//    }
    
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
//    collectionView.translatesAutoresizingMaskIntoConstraints = false
//    
//    NSLayoutConstraint.activate([
//      collectionView.topAnchor.constraint(equalTo: topAnchor),
//      collectionView.leftAnchor.constraint(equalTo: leftAnchor),
//      collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
//      collectionView.rightAnchor.constraint(equalTo: rightAnchor)
//    ])
  }
}
