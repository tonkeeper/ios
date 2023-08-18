//
//  Reusable.swift
//  Tonkeeper
//
//  Created by Grigory on 26.5.23..
//

import Foundation

protocol Reusable {
  static var reuseIdentifier: String { get }
  func prepareForReuse()
}

extension Reusable {
  static var reuseIdentifier: String {
    String(describing: Self.self)
  }
}
