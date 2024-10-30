import UIKit
import TKUIKit
import TKLocalize

final class BrowserCategoryView: UIView {
  
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
  let searchBar = BrowserSearchBar()
  let blurView = TKBlurView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    collectionView.contentInset.bottom = searchBar.bounds.height
  }
}

private extension BrowserCategoryView {
  func setup() {
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    
    searchBar.blurView.isHidden = true
    searchBar.textField.isUserInteractionEnabled = false
    searchBar.placeholder = TKLocales.Browser.SearchField.placeholder
    
    addSubview(collectionView)
    addSubview(blurView)
    addSubview(searchBar)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    searchBar.snp.makeConstraints { make in
      make.bottom.equalTo(safeAreaLayoutGuide)
      make.left.right.equalTo(self)
    }
    
    blurView.snp.makeConstraints { make in
      make.bottom.left.right.equalTo(self)
      make.top.equalTo(searchBar)
    }
  }
}
