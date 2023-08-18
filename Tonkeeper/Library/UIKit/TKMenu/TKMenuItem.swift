//
//  TKMenuItem.swift
//  Tonkeeper
//
//  Created by Grigory on 10.7.23..
//

import Foundation

struct TKMenuItem {
  enum IconPosition {
    case left
    case right
  }
  
  let icon: Image
  let iconPosition: IconPosition
  let iconSide: CGFloat
  let iconCornerRadius: CGFloat
  let leftTitle: String?
  let rightTitle: String?
  let isSelected: Bool
}
