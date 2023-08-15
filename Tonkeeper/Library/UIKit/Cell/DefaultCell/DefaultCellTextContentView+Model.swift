//
//  DefaultCellTextContentView+Model.swift
//  Tonkeeper
//
//  Created by Grigory on 15.8.23..
//

import Foundation

extension DefaultCellTextContentView {
  struct Model {
    let title: NSAttributedString?
    let amount: NSAttributedString?
    let subamount: NSAttributedString?
    let topLeftDescriptionValue: NSAttributedString?
    let topLeftDescriptionSubvalue: NSAttributedString?
    let topRightDescriptionValue: NSAttributedString?
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title
    amountView.topLabel.attributedText = model.amount
    amountView.bottomLabel.attributedText = model.subamount
    topLeftDescriptionView.leftLabel.attributedText = model.topLeftDescriptionValue
    topLeftDescriptionView.rightLabel.attributedText = model.topLeftDescriptionSubvalue
    topRightDescriptionLabel.attributedText = model.topRightDescriptionValue
    setNeedsLayout()
  }
}

extension DefaultCellTextContentView.Model {
  init(title: String?,
       amount: NSAttributedString?,
       subamount: NSAttributedString?,
       topLeftDescriptionValue: String?,
       topLeftDescriptionSubvalue: NSAttributedString?,
       topRightDescriptionValue: String?) {
    self.title = title?
      .attributed(with: .label1, alignment: .left, color: .Text.primary)
    self.amount = amount
    self.subamount = subamount
    self.topLeftDescriptionValue = topLeftDescriptionValue?
      .attributed(with: .body2, alignment: .left, color: .Text.secondary)
    self.topLeftDescriptionSubvalue = topLeftDescriptionSubvalue
    self.topRightDescriptionValue = topRightDescriptionValue?
      .attributed(with: .body2, alignment: .right, color: .Text.secondary)
  }
}
