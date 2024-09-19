import UIKit
import TKUIKit

final class TokenDetailsView: UIView {
  let navigationBar = TKUINavigationBar()
  let titleView = TKUINavigationBarTitleView()
  let listContainer = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func embedListView(_ listView: UIView) {
    listContainer.addSubview(listView)
    listView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      listView.topAnchor.constraint(equalTo: listContainer.topAnchor),
      listView.leftAnchor.constraint(equalTo: listContainer.leftAnchor),
      listView.rightAnchor.constraint(equalTo: listContainer.rightAnchor),
      listView.bottomAnchor.constraint(equalTo: listContainer.bottomAnchor)
    ])
  }
}

private extension TokenDetailsView {
  func setup() {
    backgroundColor = .Background.page
    
    navigationBar.centerView = titleView

    addSubview(listContainer)
    addSubview(navigationBar)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    navigationBar.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
    }
    listContainer.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
