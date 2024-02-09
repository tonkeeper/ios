import UIKit
import TKUIKit

final class TokenDetailsView: UIView, ConfigurableView {
  let navigationBar = UINavigationBar()
  let listContainer = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    
  }
  
  func configure(model: Model) {
    
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
    
    navigationBar.delegate = self
    navigationBar.configureDefaultAppearance()
    
    addSubview(listContainer)
    addSubview(navigationBar)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    listContainer.translatesAutoresizingMaskIntoConstraints = false
    navigationBar.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      navigationBar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      navigationBar.leftAnchor.constraint(equalTo: leftAnchor),
      navigationBar.rightAnchor.constraint(equalTo: rightAnchor),
      
      listContainer.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
      listContainer.leftAnchor.constraint(equalTo: leftAnchor),
      listContainer.rightAnchor.constraint(equalTo: rightAnchor),
      listContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }
}

extension TokenDetailsView: UINavigationBarDelegate {
  public func position(for bar: UIBarPositioning) -> UIBarPosition {
    return .topAttached
  }
}
