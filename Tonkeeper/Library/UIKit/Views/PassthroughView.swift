//
//  PassthroughView.swift
//  Tonkeeper
//
//  Created by Grigory on 8.6.23..
//

import UIKit

class PassthroughView: UIView {
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let view = super.hitTest(point, with: event)
    return view === self ? nil : view
  }
}
