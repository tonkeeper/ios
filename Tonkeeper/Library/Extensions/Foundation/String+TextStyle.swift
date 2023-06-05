//
//  String+TextStyle.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import Foundation
import UIKit.NSParagraphStyle

extension String {
  func attributed(with textStyle: TextStyle,
                  alignment: NSTextAlignment = .left,
                  lineBreakMode: NSLineBreakMode = .byWordWrapping,
                  color: UIColor = .black) -> NSAttributedString {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.minimumLineHeight = textStyle.lineHeight
    paragraphStyle.alignment = alignment
    paragraphStyle.lineBreakMode = lineBreakMode
    
    let attributes: [NSAttributedString.Key: Any] = [
      .font: textStyle.font,
      .paragraphStyle: paragraphStyle,
      .foregroundColor: color
    ]
    
    let string = textStyle.uppercased ? uppercased() : self
    return NSAttributedString(string: string, attributes: attributes)
  }
}
