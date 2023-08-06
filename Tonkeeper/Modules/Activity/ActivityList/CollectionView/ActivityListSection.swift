//
//  ActivityListSection.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import Foundation

struct ActivityListSection: Hashable {
  let id = UUID()
  let items: [AnyHashable]
}
