//
//  ActivityListSection.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import Foundation

struct ActivityListSection: Hashable {
  let date: Date
  let title: String?
  let items: [String]
  
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.date == rhs.date
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(date)
  }
}
