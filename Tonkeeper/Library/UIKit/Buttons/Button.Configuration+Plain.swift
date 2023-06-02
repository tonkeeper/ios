//
//  TKButton.Configuration+Plain.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import Foundation

extension TKButton.Configuration {
  static var primaryLarge: TKButton.Configuration {
    .init(type: .primary,
          size: .large,
          shape: .rect,
          contentInsets: .init(top: 16, left: 24, bottom: 16, right: 24))
  }
  
  static var secondaryLarge: TKButton.Configuration {
    .init(type: .secondary,
          size: .large,
          shape: .rect,
          contentInsets: .init(top: 16, left: 24, bottom: 16, right: 24))
  }
  
  static var tertiaryLarge: TKButton.Configuration {
    .init(type: .tertiary,
          size: .large,
          shape: .rect,
          contentInsets: .init(top: 16, left: 24, bottom: 16, right: 24))
  }
  
  static var primaryMedium: TKButton.Configuration {
    .init(type: .primary,
          size: .medium,
          shape: .rect,
          contentInsets: .init(top: 11, left: 20, bottom: 13, right: 20))
  }
  
  static var secondaryMedium: TKButton.Configuration {
    .init(type: .secondary,
          size: .medium,
          shape: .rect,
          contentInsets: .init(top: 11, left: 20, bottom: 13, right: 20))
  }
  
  static var tertiaryMedium: TKButton.Configuration {
    .init(type: .tertiary,
          size: .medium,
          shape: .rect,
          contentInsets: .init(top: 11, left: 20, bottom: 13, right: 20))
  }
  
  static var primarySmall: TKButton.Configuration {
    .init(type: .primary,
          size: .small,
          shape: .rect,
          contentInsets: .init(top: 8, left: 16, bottom: 8, right: 16))
  }
  
  static var secondarySmall: TKButton.Configuration {
    .init(type: .secondary,
          size: .small,
          shape: .rect,
          contentInsets: .init(top: 8, left: 16, bottom: 8, right: 16))
  }
  
  static var tertiarySmall: TKButton.Configuration {
    .init(type: .tertiary,
          size: .small,
          shape: .rect,
          contentInsets: .init(top: 8, left: 16, bottom: 8, right: 16))
  }
}
