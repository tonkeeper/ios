//
//  TokensListSection.swift
//  Tonkeeper
//
//  Created by Grigory on 26.5.23..
//

import Foundation

struct TokensListSection {
  typealias Identifier = UUID
  
  enum SectionType {
    case token
    case application
    case collectibles
  }
  
  let id = Identifier()
  let type: SectionType
  let items: [AnyHashable]
}
