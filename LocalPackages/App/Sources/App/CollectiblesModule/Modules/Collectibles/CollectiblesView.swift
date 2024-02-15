import UIKit
import TKUIKit

final class CollectiblesView: UIView {
  let navigationBarView = TKNavigationBar()
  
  let listContainer = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func showList() {
    listContainer.isHidden = false
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

private extension CollectiblesView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(listContainer)
    addSubview(navigationBarView)

    listContainer.translatesAutoresizingMaskIntoConstraints = false
    navigationBarView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      navigationBarView.topAnchor.constraint(equalTo: topAnchor),
      navigationBarView.leftAnchor.constraint(equalTo: leftAnchor),
      navigationBarView.rightAnchor.constraint(equalTo: rightAnchor),

      listContainer.topAnchor.constraint(equalTo: topAnchor),
      listContainer.leftAnchor.constraint(equalTo: leftAnchor),
      listContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
      listContainer.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
