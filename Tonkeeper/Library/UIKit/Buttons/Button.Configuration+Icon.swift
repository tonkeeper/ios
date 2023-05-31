//
//  Button.Configuration+Icon.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import Foundation

extension Button.Configuration {
  static var icon: Button.Configuration {
    .init(type: .tertiary,
          size: .welter,
          shape: .circle,
          contentInsets: .zero)
  }
}
