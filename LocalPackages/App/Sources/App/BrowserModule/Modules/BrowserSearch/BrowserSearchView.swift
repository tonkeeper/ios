import UIKit
import TKUIKit
import SnapKit

final class BrowserSearchView: TKView {
  var keyboardHeight: CGFloat = 0 {
    didSet {
      searchBar.snp.remakeConstraints { make in
        make.left.right.equalTo(self)
        make.bottom.equalTo(self).offset(-keyboardHeight)
      }
      collectionView.contentInset.bottom = keyboardHeight
    }
  }
  
  let searchBar = BrowserSearchBar()
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
  let emptyView = UIView()
  let emptyLabel = UILabel()
  
  override func setup() {
    backgroundColor = .Background.page
    collectionView.backgroundColor = .clear
    searchBar.textField.returnKeyType = .go
    
    addSubview(collectionView)
    addSubview(searchBar)
    addSubview(emptyView)
    emptyView.addSubview(emptyLabel)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    searchBar.snp.makeConstraints { make in
      make.left.right.equalTo(self)
      make.bottom.equalTo(safeAreaLayoutGuide)
    }
    
    emptyView.snp.makeConstraints { make in
      make.left.right.equalTo(self)
      make.top.equalTo(safeAreaLayoutGuide)
      make.bottom.equalTo(searchBar.snp.top)
    }
    
    emptyLabel.snp.makeConstraints { make in
      make.left.right.equalTo(emptyView).inset(32)
      make.centerY.equalTo(emptyView)
    }
    
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
