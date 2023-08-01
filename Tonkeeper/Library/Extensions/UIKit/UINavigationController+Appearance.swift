//
//  UINavigationController+Appearance.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

extension UINavigationController {
  func configureDefaultAppearance() {
    let navigationBarAppearance = UINavigationBarAppearance()
    navigationBarAppearance.configureWithOpaqueBackground()
    navigationBarAppearance.backgroundColor = .Background.page
    navigationBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.Text.primary,
                                                   .font: TextStyle.h3.font]
    navigationBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.Text.primary,
                                                        .font: TextStyle.h3.font]

    navigationBar.tintColor = .Accent.blue
    navigationBar.standardAppearance = navigationBarAppearance
    navigationBar.compactAppearance = navigationBarAppearance
    if #available(iOS 15.0, *) {
      navigationBar.compactScrollEdgeAppearance = navigationBarAppearance
    }
  }
  
  func configureTransparentAppearance() {
    let navigationBarAppearance = UINavigationBarAppearance()
    navigationBarAppearance.configureWithTransparentBackground()
    
    navigationBar.standardAppearance = navigationBarAppearance
    navigationBar.compactAppearance = navigationBarAppearance
    if #available(iOS 15.0, *) {
      navigationBar.compactScrollEdgeAppearance = navigationBarAppearance
    }
  }
}
