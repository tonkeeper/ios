//
//  UILabel+TextStyle.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

extension UILabel {
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
