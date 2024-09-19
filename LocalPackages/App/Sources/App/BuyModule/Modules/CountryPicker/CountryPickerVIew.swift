import UIKit
import TKUIKit
import SnapKit

final class CountryPickerView: TKView {
  let topBar = CountryPickerTopBarView()
  let searchBar = BrowserSearchBar()
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: .init())
  
  private var topBarTopConstrant: Constraint?
  private var searchBarTopConstrant: Constraint?

  override func setup() {
    super.setup()
    
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    
    searchBar.backgroundColor = .Background.page
    searchBar.isBlur = false
    searchBar.padding = UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)
    
    addSubview(collectionView)
    addSubview(searchBar)
    addSubview(topBar)
    
    setupConstraints()
  }
  
  func hideTopBar() {
    searchBarTopConstrant?.update(offset: 16)
    topBarTopConstrant?.update(offset: -topBar.intrinsicContentSize.height)
    layoutIfNeeded()
  }
  
  func showTopBar() {
    searchBarTopConstrant?.update(offset: 0)
    topBarTopConstrant?.update(offset: 0)
    layoutIfNeeded()
  }
  
  override func setupConstraints() {
    topBar.snp.makeConstraints { make in
      topBarTopConstrant = make.top.equalTo(self).constraint
      make.left.right.equalTo(self)
    }
    
    collectionView.snp.makeConstraints { make in
      make.top.equalTo(searchBar.snp.bottom)
      make.left.right.bottom.equalTo(self)
    }
    
    searchBar.snp.makeConstraints { make in
      searchBarTopConstrant = make.top.equalTo(topBar.snp.bottom).constraint
      make.left.right.equalTo(self)
    }
  }
}

