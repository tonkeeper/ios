
import UIKit
import TKUIKit

final class SettingsPurchasesView: UIView {
  
  let navigationBar = TKUINavigationBar()
  let titleView = TKUINavigationBarTitleView()
  let collectionView = TKUICollectionView(frame: .zero,
                                          collectionViewLayout: UICollectionViewLayout())
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
   
    navigationBar.layoutIfNeeded()
    collectionView.contentInset.top = navigationBar.bounds.height
    collectionView.contentInset.bottom = safeAreaInsets.bottom + 16
  }
}

private extension SettingsPurchasesView {
  func setup() {
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    collectionView.contentInsetAdjustmentBehavior = .never
    
    navigationBar.scrollView = collectionView
    navigationBar.centerView = titleView
    
    addSubview(collectionView)
    addSubview(navigationBar)
    
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    navigationBar.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
    }
  }
}
