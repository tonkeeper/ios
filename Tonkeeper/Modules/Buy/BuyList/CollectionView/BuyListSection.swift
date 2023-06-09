//
//  BuyListSection.swift
//  Tonkeeper
//
//  Created by Grigory on 9.6.23..
//

import Foundation

struct BuyListSection: Hashable {
  enum SectionType {
    case services
    case button
  }
  
  let id = UUID()
  let type: SectionType
  let items: [AnyHashable]
}
