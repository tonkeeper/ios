//
//  Button.Configuration+Header.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import Foundation

extension Button.Configuration {
  enum Header {
    static var button: Button.Configuration {
      .init(type: .secondary,
            size: .xsmall,
            shape: .circle,
            contentInsets: .zero)
    }
  }
}
