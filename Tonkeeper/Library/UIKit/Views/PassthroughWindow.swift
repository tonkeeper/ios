//
//  PassthroughWindow.swift
//  Tonkeeper
//
//  Created by Grigory on 31.7.23..
//

import UIKit

class PassthroughWindow: UIWindow {
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let view = super.hitTest(point, with: event)
    return view === self ? nil : view
  }
}
