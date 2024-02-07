import UIKit
import TKUIKit

public final class SettingsRootView: UIView {
  let navigationBar = UINavigationBar()
//  let navigationBar = NavigationBarView()
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension SettingsRootView {
  func setup() {
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    
    navigationBar.delegate = self
    navigationBar.configureDefaultAppearance()
    
    addSubview(navigationBar)
    addSubview(collectionView)

    setupConstraints()
  }
  
  func setupConstraints() {
    navigationBar.translatesAutoresizingMaskIntoConstraints = false
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      navigationBar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      navigationBar.leftAnchor.constraint(equalTo: leftAnchor),
      navigationBar.rightAnchor.constraint(equalTo: rightAnchor),
      
      collectionView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
      collectionView.leftAnchor.constraint(equalTo: leftAnchor),
      collectionView.rightAnchor.constraint(equalTo: rightAnchor),
      collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }
}

extension SettingsRootView: UINavigationBarDelegate {
  public func position(for bar: UIBarPositioning) -> UIBarPosition {
    return .topAttached
  }
}
