//
//  String+TextStyle.swift
//  
//
//  Created by Grigory on 22.9.23..
//

import Foundation
import UIKit.NSParagraphStyle

public extension String {
  func attributed(with textStyle: TKUIKit.TextStyle,
                  alignment: NSTextAlignment = .left,
                  lineBreakMode: NSLineBreakMode = .byTruncatingTail,
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

