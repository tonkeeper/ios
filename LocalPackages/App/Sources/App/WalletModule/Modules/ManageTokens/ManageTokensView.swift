import UIKit
import TKUIKit

final class ManageTokensView: UIView {
  
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

private extension ManageTokensView {
  func setup() {
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    
    navigationBar.scrollView = collectionView
    navigationBar.centerView = titleView
    
    addSubview(collectionView)
    addSubview(navigationBar)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    navigationBar.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
    }
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
