//
//  ServiceCellContentView+Model.swift
//  Tonkeeper
//
//  Created by Grigory on 9.6.23..
//

import UIKit

extension ServiceCellContentView {
  struct Model: Hashable {
    let logo: Image
    let title: NSAttributedString
    let description: NSAttributedString?
    let token: NSAttributedString?
  }
}

extension ServiceCellContentView.Model {
  init(logo: Image,
       title: String,
       description: String?,
       token: String?) {
    self.logo = logo
    self.title = title
      .attributed(with: .label1, alignment: .left, color: .Text.primary)
    self.description = description?
      .attributed(with: .body2, alignment: .left, color: .Text.secondary)
    self.token = token?
      .attributed(with: .body4, alignment: .left, color: .Text.secondary)
  }
}
