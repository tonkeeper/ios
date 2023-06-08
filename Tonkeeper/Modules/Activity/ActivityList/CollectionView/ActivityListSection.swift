//
//  ActivityListSection.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import Foundation

struct ActivityListSection: Hashable {
  enum SectionType {
    case transaction
    case date
  }
  
  let id = UUID()
  let type: SectionType
  let items: [AnyHashable]
}
