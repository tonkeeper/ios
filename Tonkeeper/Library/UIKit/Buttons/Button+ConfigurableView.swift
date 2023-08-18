//
//  TKButton+ConfigurableView.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import UIKit

extension TKButton: ConfigurableView {
  struct Model {
    let title: String?
    let icon: UIImage?
    let iconPosition: IconPosition
    
    init(title: String? = nil,
         icon: UIImage? = nil,
         iconPosition: IconPosition = .left) {
      self.title = title
      self.icon = icon
      self.iconPosition = iconPosition
    }
  }
  
  func configure(model: Model) {
    title = model.title
    titleLabel.isHidden = model.title == nil
    
    icon = model.icon
    iconImageView.isHidden = model.icon == nil
    
    iconPosition = model.iconPosition
  }
}
