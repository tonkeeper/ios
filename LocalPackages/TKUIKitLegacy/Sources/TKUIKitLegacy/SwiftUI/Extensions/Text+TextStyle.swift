//
//  Text+TextStyle.swift
//  
//
//  Created by Grigory Serebryanyy on 21.10.2023.
//

import SwiftUI

public extension Text {
  func textStyle(_ textStyle: TKUIKitLegacy.TextStyle) -> some View {
    self
      .font(Font(textStyle.font))
      .lineSpacing(textStyle.lineSpacing)
  }
}
