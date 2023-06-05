//
//  Button.Configuration+Icon.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import Foundation

extension TKButton.Configuration {
  static var icon: TKButton.Configuration {
    .init(type: .tertiary,
          size: .welter,
          shape: .circle,
          contentInsets: .zero)
  }
}
