//
//  NSLayoutConstraint+Priority.swift
//  Tonkeeper
//
//  Created by Grigory on 30.5.23..
//

import UIKit

extension NSLayoutConstraint {
  func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
    self.priority = priority
    return self
  }
}
