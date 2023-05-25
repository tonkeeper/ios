//
//  IconButton+ConfigurableView.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import UIKit

extension IconButton: ConfigurableView {
  struct Model {
    let buttonModel: Button.Model
    let title: String
  }
  
  func configure(model: Model) {
    button.configure(model: model.buttonModel)
    titleLabel.text = model.title
  }
}
