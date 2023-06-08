//
//  DefaultCellContentView+Model.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import UIKit

extension DefaultCellContentView {
  
  struct Model {
    let textContentModel: DefaultCellTextContentView.Model
    let image: UIImage?
  }
}

extension DefaultCellTextContentView {
  struct Model {
    let leftTopTitle: NSAttributedString
    let leftTopRightTitle: NSAttributedString?
    let rightTopTitle: NSAttributedString
    let leftMiddleTitle: NSAttributedString?
    let leftMiddleRightTitle: NSAttributedString?
    let rightMiddleTitle: NSAttributedString?
    let leftBottomTitle: NSAttributedString?
    let rightBottomTitle: NSAttributedString?
  }
}

extension DefaultCellTextContentView.Model {
  init(leftTopTitle: String,
       leftTopRightTitle: String?,
       rightTopTitle: NSAttributedString,
       leftMiddleTitle: String?,
       leftMiddleRightTitle: NSAttributedString?,
       rightMiddleTitle: String?,
       leftBottomTitle: String?,
       rightBottomTitle: String?) {
    self.leftTopTitle = leftTopTitle
      .attributed(with: .label1, alignment: .left, color: .Text.primary)
    self.leftTopRightTitle = leftTopRightTitle?
      .attributed(with: .label1, alignment: .left, color: .Text.tertiary)
    self.rightTopTitle = rightTopTitle
    self.leftMiddleTitle = leftMiddleTitle?
      .attributed(with: .body2, alignment: .left, color: .Text.secondary)
    self.leftMiddleRightTitle = leftMiddleRightTitle
    self.rightMiddleTitle = rightMiddleTitle?
      .attributed(with: .body2, alignment: .left, color: .Text.secondary)
    self.leftBottomTitle = leftBottomTitle?
      .attributed(with: .body2, alignment: .left, color: .Text.secondary)
    self.rightBottomTitle = rightBottomTitle?
      .attributed(with: .body2, alignment: .left, color: .Text.secondary)
  }
}
