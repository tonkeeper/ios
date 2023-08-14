//
//  ActivityListSection.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import Foundation

enum ActivityListSection: Hashable {
  case events(EventsSectionData)
  case pagination(Pagination)
  case shimmer(shimmers: [String])
  
  enum Pagination: Hashable {
    case loading
    case error(title: String?)
    
    func hash(into hasher: inout Hasher) {}
  }
  
  struct EventsSectionData: Hashable {
    let date: Date
    let title: String?
    let items: [String]
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(date)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.hashValue == rhs.hashValue
    }
  }
}
