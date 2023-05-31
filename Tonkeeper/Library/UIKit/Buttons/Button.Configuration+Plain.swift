//
//  Button.Configuration+Plain.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import Foundation

extension Button.Configuration {
  static var primaryLarge: Button.Configuration {
    .init(type: .primary,
          size: .large,
          shape: .rect,
          contentInsets: .init(top: 16, left: 24, bottom: 16, right: 24))
  }
  
  static var secondaryLarge: Button.Configuration {
    .init(type: .secondary,
          size: .large,
          shape: .rect,
          contentInsets: .init(top: 16, left: 24, bottom: 16, right: 24))
  }
  
  static var tertiaryLarge: Button.Configuration {
    .init(type: .tertiary,
          size: .large,
          shape: .rect,
          contentInsets: .init(top: 16, left: 24, bottom: 16, right: 24))
  }
  
  static var primaryMedium: Button.Configuration {
    .init(type: .primary,
          size: .medium,
          shape: .rect,
          contentInsets: .init(top: 11, left: 20, bottom: 13, right: 20))
  }
  
  static var secondaryMedium: Button.Configuration {
    .init(type: .secondary,
          size: .medium,
          shape: .rect,
          contentInsets: .init(top: 11, left: 20, bottom: 13, right: 20))
  }
  
  static var tertiaryMedium: Button.Configuration {
    .init(type: .tertiary,
          size: .medium,
          shape: .rect,
          contentInsets: .init(top: 11, left: 20, bottom: 13, right: 20))
  }
  
  static var primarySmall: Button.Configuration {
    .init(type: .primary,
          size: .small,
          shape: .rect,
          contentInsets: .init(top: 8, left: 16, bottom: 8, right: 16))
  }
  
  static var secondarySmall: Button.Configuration {
    .init(type: .secondary,
          size: .small,
          shape: .rect,
          contentInsets: .init(top: 8, left: 16, bottom: 8, right: 16))
  }
  
  static var tertiarySmall: Button.Configuration {
    .init(type: .tertiary,
          size: .small,
          shape: .rect,
          contentInsets: .init(top: 8, left: 16, bottom: 8, right: 16))
  }
}
