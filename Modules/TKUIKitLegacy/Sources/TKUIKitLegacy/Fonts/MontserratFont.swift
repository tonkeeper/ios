//
//  MontserratFont.swift
//
//
//  Created by Grigory on 22.9.23..
//

import UIKit

struct MontserratFont {
  static let medium: MontserratFont? = MontserratFont(name: "Montserrat-Medium")
  static let bold: MontserratFont? = MontserratFont(name: "Montserrat-Bold")
  static let semibold: MontserratFont? = MontserratFont(name: "Montserrat-SemiBold")
  
  
  let name: String
  
  init?(name: String) {
    self.name = name
    do {
      try registerFont(named: name)
    } catch {
      assert(true, "Can't register font with name: \(name)")
      return nil
    }
  }
}
