//
//  UITabBarController+Appearance.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit
import TKUIKitLegacy

extension UITabBarController {
  func configureAppearance() {
    let itemAppearance = UITabBarItemAppearance()
    itemAppearance.normal.titleTextAttributes = [.font: TextStyle.label3.font,
                                                 .foregroundColor: UIColor.TabBar.inactiveIcon]
    itemAppearance.normal.iconColor = .TabBar.inactiveIcon
    itemAppearance.selected.titleTextAttributes = [.font: TextStyle.label3.font,
                                                 .foregroundColor: UIColor.TabBar.activeIcon]
    itemAppearance.selected.iconColor = .TabBar.activeIcon
    
    func createTabBarAppearance() -> UITabBarAppearance {
      let appearance = UITabBarAppearance()
      appearance.configureWithOpaqueBackground()
      appearance.backgroundColor = .Background.transparent
      appearance.stackedLayoutAppearance = itemAppearance
      return appearance
    }
   
    let tabBarAppearance = createTabBarAppearance()
    tabBarAppearance.shadowColor = .Separator.common
    tabBar.standardAppearance = tabBarAppearance
    
    if #available(iOS 15.0, *) {
      let scrollEdgeAppearance = createTabBarAppearance()
      scrollEdgeAppearance.shadowColor = .clear
      tabBar.scrollEdgeAppearance = scrollEdgeAppearance
    }
  }
}
