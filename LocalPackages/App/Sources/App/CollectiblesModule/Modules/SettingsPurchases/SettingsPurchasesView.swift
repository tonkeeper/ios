
import UIKit
import TKUIKit

final class SettingsPurchasesView: UIView {
  
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

private extension SettingsPurchasesView {
  func setup() {
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    
    addSubview(collectionView)
    
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
