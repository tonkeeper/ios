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
    let adjustment = textStyle.lineHeight > textStyle.font.lineHeight ? 2.0 : 1.0
    let baselineOffset = (textStyle.lineHeight - textStyle.font.lineHeight) / 2.0 / adjustment
    
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.minimumLineHeight = textStyle.lineHeight
    paragraphStyle.maximumLineHeight = textStyle.lineHeight
    paragraphStyle.alignment = alignment
    paragraphStyle.lineBreakMode = lineBreakMode
    
    let attributes: [NSAttributedString.Key: Any] = [
      .font: textStyle.font,
      .foregroundColor: color,
      .paragraphStyle: paragraphStyle,
      .baselineOffset: baselineOffset
    ]
    let string = textStyle.uppercased ? uppercased() : self
    return NSAttributedString(string: string, attributes: attributes)
  }
}

