//
//  TKButton.Configuration+Header.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import Foundation

extension TKButton.Configuration {
  enum Header {
    static var button: TKButton.Configuration {
      .init(type: .secondary,
            size: .xsmall,
            shape: .circle,
            contentInsets: .zero)
    }
  }
}