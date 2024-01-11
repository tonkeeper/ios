//
//  UIFont+Montserrat.swift
//
//
//  Created by Grigory on 22.9.23..
//

import UIKit

public extension UIFont {
  static func montserratBold(size: CGFloat) -> UIFont {
    montserratFont(.bold, size: size) ?? .systemFont(ofSize: size, weight: .bold)
  }
  
  static func montserratSemiBold(size: CGFloat) -> UIFont {
    montserratFont(.semibold, size: size) ?? .systemFont(ofSize: size, weight: .bold)
  }

  static func montserratMedium(size: CGFloat) -> UIFont {
    montserratFont(.medium, size: size) ?? .systemFont(ofSize: size, weight: .bold)
  }
  
  private static func montserratFont(_ montserratFont: MontserratFont?, size: CGFloat) -> UIFont? {
    guard let name = montserratFont?.name,
          let font = UIFont(name: name, size: size) else {
      assert(true, "Can't load font")
      return nil
    }
    return font
  }
}

