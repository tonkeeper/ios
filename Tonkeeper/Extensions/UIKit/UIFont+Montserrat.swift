//
//  UIFont+Montserrat.swift
//  Tonkeeper
//
//  Created by Grigory on 22.5.23..
//

import UIKit

extension UIFont {
  static func montserratBold(size: CGFloat) -> UIFont {
    .font(with: "Montserrat-Bold", size: size) ?? .systemFont(ofSize: size, weight: .bold)
  }
  
  static func montserratSemiBold(size: CGFloat) -> UIFont {
    .font(with: "Montserrat-SemiBold", size: size) ?? .systemFont(ofSize: size, weight: .semibold)
  }

  static func montserratMedium(size: CGFloat) -> UIFont {
    .font(with: "Montserrat-Medium", size: size) ?? .systemFont(ofSize: size, weight: .medium)
  }
  
  private static func font(with name: String, size: CGFloat) -> UIFont? {
    let font = UIFont.init(name: name, size: size)
    assert(font != nil, "Can't load font with name: \(name)")
    return font
  }
}
