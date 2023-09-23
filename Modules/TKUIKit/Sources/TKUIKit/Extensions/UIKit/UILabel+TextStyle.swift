//
//  UILabel+TextStyle.swift
//
//
//  Created by Grigory on 22.9.23..
//

import UIKit

public extension UILabel {
  func applyTextStyleFont(_ textStyle: TextStyle) {
    font = textStyle.font
  }
  
  func applyTextStyle(text: String,
                      _ textStyle: TextStyle,
                      alignment: NSTextAlignment = .left,
                      lineBreakMode: NSLineBreakMode = .byWordWrapping,
                      color: UIColor = .black) {
    attributedText = text.attributed(with: textStyle,
                                     alignment: alignment,
                                     lineBreakMode: lineBreakMode,
                                     color: color)
  }
}

