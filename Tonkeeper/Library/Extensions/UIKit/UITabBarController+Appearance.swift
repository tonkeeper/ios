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
    itemAppearance.normal.titleTextAttributes = [.font: TextStyle.label3.font,
                                                 .foregroundColor: UIColor.TabBar.inactiveIcon]
    itemAppearance.normal.iconColor = .TabBar.inactiveIcon
    itemAppearance.selected.titleTextAttributes = [.font: TextStyle.label3.font,
                                                 .foregroundColor: UIColor.TabBar.activeIcon]
    itemAppearance.selected.iconColor = .TabBar.activeIcon
   
    let tabBarAppearance = UITabBarAppearance()
    tabBarAppearance.configureWithOpaqueBackground()
    tabBarAppearance.backgroundColor = .Background.transparent
    tabBarAppearance.stackedLayoutAppearance = itemAppearance
    tabBarAppearance.shadowColor = .Separator.common

    tabBar.standardAppearance = tabBarAppearance
    if #available(iOS 15.0, *) {
      tabBar.scrollEdgeAppearance = tabBarAppearance
    }
  }
}
