import UIKit
import TKUIKit
import SnapKit

final class CurrencyListView: UIView {
  
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: .init())
  let titleView = ModalTitleView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension CurrencyListView {
  func setup() {
    addSubview(collectionView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
