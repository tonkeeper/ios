//
//  TextStyle.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

public struct TextStyle {
  public let font: UIFont
  public let lineHeight: CGFloat
  public let uppercased: Bool
  
  public var lineSpacing: CGFloat {
      return lineHeight - font.lineHeight
  }
  
  public init(font: UIFont,
              lineHeight: CGFloat,
              uppercased: Bool = false) {
    self.font = font
    self.lineHeight = lineHeight
    self.uppercased = uppercased
  }
}

public extension TextStyle {
  static let num1: TextStyle = .init(
    font: .montserratSemiBold(size: 32),
    lineHeight: 40
  )
  
  static let h1: TextStyle = .init(
    font: .montserratBold(size: 32),
    lineHeight: 40
  )
  
  static let num2: TextStyle = .init(
    font: .montserratSemiBold(size: 28),
    lineHeight: 36
  )
  
  static let h2: TextStyle = .init(
    font: .montserratBold(size: 24),
    lineHeight: 32)
  
  static let h3: TextStyle = .init(
    font: .montserratBold(size: 20),
    lineHeight: 28
  )
  
  static let label1: TextStyle = .init(
    font: .montserratSemiBold(size: 16),
    lineHeight: 24
  )
  
  static let label2: TextStyle = .init(
    font: .montserratSemiBold(size: 14),
    lineHeight: 20
  )
  
  static let label3: TextStyle = .init(
    font: .montserratSemiBold(size: 12),
    lineHeight: 16
  )
  
  static let body1: TextStyle = .init(
    font: .montserratMedium(size: 16),
    lineHeight: 24
  )
  
  static let body2: TextStyle = .init(
    font: .montserratMedium(size: 14),
    lineHeight: 20
  )
  
  static let body3: TextStyle = .init(
    font: .montserratMedium(size: 12),
    lineHeight: 16
  )
  
  static let body4: TextStyle = .init(
    font: .montserratSemiBold(size: 10),
    lineHeight: 14,
    uppercased: true
  )
}
