//
//  UINavigationController+Appearance.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit
import TKUIKit

extension UINavigationController {
  func configureDefaultAppearance() {
    let standartAppearance = UINavigationBarAppearance()
    standartAppearance.configureWithOpaqueBackground()
    standartAppearance.backgroundColor = .Background.page
    standartAppearance.shadowColor = .clear
    standartAppearance.titleTextAttributes = [.foregroundColor: UIColor.Text.primary,
                                              .font: TextStyle.h3.font]
    standartAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.Text.primary,
                                                   .font: TextStyle.h1.font]

    navigationBar.standardAppearance = standartAppearance
    navigationBar.compactAppearance = standartAppearance
    navigationBar.scrollEdgeAppearance = standartAppearance
    if #available(iOS 15.0, *) {
      navigationBar.compactScrollEdgeAppearance = standartAppearance
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
