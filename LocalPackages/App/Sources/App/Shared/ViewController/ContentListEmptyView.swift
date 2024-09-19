import UIKit
import TKUIKit

final class ContentListEmptyView: UIView {
  let navigationBarView = TKNavigationBar()

  private let emptyViewContainer = UIView()
  private let listViewContainer = UIView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func embedEmptyView(_ view: UIView) {
    emptyViewContainer.subviews.forEach { $0.removeFromSuperview() }
    emptyViewContainer.addSubview(view)
    view.snp.makeConstraints { make in
      make.edges.equalTo(emptyViewContainer)
    }
  }
  
  func embedListView(_ view: UIView) {
    listViewContainer.subviews.forEach { $0.removeFromSuperview() }
    listViewContainer.addSubview(view)
    view.snp.makeConstraints { make in
      make.edges.equalTo(listViewContainer)
    }
  }
  
  func showEmpty() {
    emptyViewContainer.isHidden = false
    listViewContainer.isHidden = true
  }
  
  func showList() {
    emptyViewContainer.isHidden = true
    listViewContainer.isHidden = false
  }
}

private extension ContentListEmptyView {
  func setup() {
    backgroundColor = .Background.page
    addSubview(emptyViewContainer)
    addSubview(listViewContainer)
    addSubview(navigationBarView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    emptyViewContainer.snp.makeConstraints { make in
      make.edges.equalTo(safeAreaLayoutGuide)
    }
    listViewContainer.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    navigationBarView.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
    }
  }
}
