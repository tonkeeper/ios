//
//  TabBarController.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit

final class TabBarController: UITabBarController {
  
  private let appSettings = AppSettings()
  private let badgeView = BadgeView()
  
  override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nil, bundle: nil)
    NotificationCenter.default
      .addObserver(
        self,
        selector: #selector(updateBackupBadge),
        name: Notification.Name("isNeedToMakeBackupUpdated"), object: nil
      )
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    NotificationCenter.default.removeObserver(
      self,
      name: Notification.Name("isNeedToMakeBackupUpdated"),
      object: nil)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    updateBackupBadge()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: true)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.setNavigationBarHidden(false, animated: true)
  }
  
  override func setViewControllers(_ viewControllers: [UIViewController]?, animated: Bool) {
    super.setViewControllers(viewControllers, animated: animated)
    updateBackupBadge()
  }
}

private extension TabBarController {
  @objc
  func updateBackupBadge() {
    badgeView.removeFromSuperview()
    
    guard appSettings.isNeedToMakeBackup,
    let lastTabBarButton = tabBar.subviews.last else { return }
    lastTabBarButton.addSubview(badgeView)
    badgeView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      badgeView.centerXAnchor.constraint(equalTo: lastTabBarButton.centerXAnchor, constant: 16),
      badgeView.centerYAnchor.constraint(equalTo: lastTabBarButton.centerYAnchor, constant: -16),
    ])
  }
}

final class BadgeView: UIView {
  override init(frame: CGRect) {
    super.init(frame: .zero)
    backgroundColor = .Accent.red
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: 6, height: 6)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.height/2
  }
}
