import UIKit
import TKUIKit

final class TokenDetailsView: UIView, ConfigurableView {
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

    addSubview(listContainer)
    setupConstraints()
  }
  
  func setupConstraints() {
    listContainer.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      listContainer.topAnchor.constraint(equalTo: topAnchor),
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
