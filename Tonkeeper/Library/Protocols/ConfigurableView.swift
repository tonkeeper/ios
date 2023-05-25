//
//  ConfigurableView.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import UIKit

protocol ConfigurableView: UIView {
  associatedtype Model
  func configure(model: Model)
}
