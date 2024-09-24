import UIKit
import TKUIKit
import TKLocalize

final class BrowserView: UIView {
  
  let headerView = BrowserHeaderView()
  let exploreContainer = UIView()
  let connectedContainer = UIView()
  let searchBar = BrowserSearchBar()
  let blurView = TKBlurView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func embedExploreView(_ exploreView: UIView) {
    exploreContainer.addSubview(exploreView)
    
    exploreView.snp.makeConstraints { make in
      make.edges.equalTo(exploreContainer)
    }
  }
  
  func embedConnectedView(_ connectedView: UIView) {
    connectedContainer.addSubview(connectedView)
    
    connectedView.snp.makeConstraints { make in
      make.edges.equalTo(connectedContainer)
    }
  }
}

private extension BrowserView {
  func setup() {
    backgroundColor = .Background.page
    searchBar.blurView.isHidden = true
    searchBar.textField.isUserInteractionEnabled = false
    searchBar.placeholder = TKLocales.Browser.SearchField.placeholder

    addSubviews(
      exploreContainer,
      connectedContainer,
      headerView,
      blurView,
      searchBar
    )
    setupConstraints()
  }
  
  func setupConstraints() {
    headerView.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
    }
    
    exploreContainer.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    connectedContainer.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    searchBar.snp.makeConstraints { make in
      make.left.right.equalTo(self)
      make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
    }
    
    blurView.snp.makeConstraints { make in
      make.bottom.left.right.equalTo(self)
      make.top.equalTo(searchBar)
    }
  }
}
