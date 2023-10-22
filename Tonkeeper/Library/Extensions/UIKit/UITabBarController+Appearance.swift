//
//  UITabBarController+Appearance.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit
import TKUIKit

extension UITabBarController {
  func configureAppearance() {
    let itemAppearance = UITabBarItemAppearance()
    itemAppearance.normal.titleTextAttributes = [.font: TextStyle.label3.font]
    
    let tabBarAppearance = UITabBarAppearance()
    tabBarAppearance.configureWithOpaqueBackground()
    tabBarAppearance.backgroundColor = .Background.transparent
    tabBarAppearance.stackedLayoutAppearance = itemAppearance
    tabBarAppearance.shadowColor = .Separator.common
    
    tabBar.standardAppearance = tabBarAppearance
    if #available(iOS 15.0, *) {
      tabBar.scrollEdgeAppearance = tabBarAppearance
    }
    tabBar.tintColor = .TabBar.activeIcon
    tabBar.unselectedItemTintColor = .TabBar.inactiveIcon
  }
}
