//
//  TKButton+ConfigurableView.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import UIKit

extension TKButton: ConfigurableView {
  struct Model {
    enum Title {
      case string(String?)
      case attributedString(NSAttributedString?)
    }
    let title: Title?
    let icon: UIImage?
    let iconPosition: IconPosition
    
    init(title: Title? = nil,
         icon: UIImage? = nil,
         iconPosition: IconPosition = .left) {
      self.title = title
      self.icon = icon
      self.iconPosition = iconPosition
    }
  }
  
  func configure(model: Model) {
//    title = model.title
    switch model.title {
    case .string(let string):
      title = string?.attributed(with: configuration.size.textStyle, alignment: .center, color: configuration.type.tintColors[.normal] ?? .white)
    case .attributedString(let string):
      title = string
    case .none:
      title = nil
    }
    titleLabel.isHidden = model.title == nil
    
    icon = model.icon
    iconImageView.isHidden = model.icon == nil
    
    iconPosition = model.iconPosition
  }
}
