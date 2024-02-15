import UIKit
import TKUIKit

final class HistoryView: UIView {
  let navigationBarView = TKNavigationBar()
  
  let listContainer = UIView()
  let emptyContainer = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func showEmptyState() {
    emptyContainer.isHidden = false
    listContainer.isHidden = true
  }
  
  func showList() {
    listContainer.isHidden = false
    emptyContainer.isHidden = true
  }
  
  func addEmptyContentView(view: UIView) {
    emptyContainer.subviews.forEach { $0.removeFromSuperview() }
    emptyContainer.addSubview(view)
    view.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: emptyContainer.topAnchor),
      view.leftAnchor.constraint(equalTo: emptyContainer.leftAnchor),
      view.bottomAnchor.constraint(equalTo: emptyContainer.bottomAnchor),
      view.rightAnchor.constraint(equalTo: emptyContainer.rightAnchor)
    ])
  }
  
  func addListContentView(view: UIView) {
    listContainer.subviews.forEach { $0.removeFromSuperview() }
    listContainer.addSubview(view)
    view.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: listContainer.topAnchor),
      view.leftAnchor.constraint(equalTo: listContainer.leftAnchor),
      view.bottomAnchor.constraint(equalTo: listContainer.bottomAnchor),
      view.rightAnchor.constraint(equalTo: listContainer.rightAnchor)
    ])
  }
}

private extension HistoryView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(listContainer)
    addSubview(emptyContainer)
    addSubview(navigationBarView)

    emptyContainer.translatesAutoresizingMaskIntoConstraints = false
    listContainer.translatesAutoresizingMaskIntoConstraints = false
    navigationBarView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      navigationBarView.topAnchor.constraint(equalTo: topAnchor),
      navigationBarView.leftAnchor.constraint(equalTo: leftAnchor),
      navigationBarView.rightAnchor.constraint(equalTo: rightAnchor),
      
      emptyContainer.topAnchor.constraint(equalTo: topAnchor),
      emptyContainer.leftAnchor.constraint(equalTo: leftAnchor),
      emptyContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
      emptyContainer.rightAnchor.constraint(equalTo: rightAnchor),
      
      listContainer.topAnchor.constraint(equalTo: topAnchor),
      listContainer.leftAnchor.constraint(equalTo: leftAnchor),
      listContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
      listContainer.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
