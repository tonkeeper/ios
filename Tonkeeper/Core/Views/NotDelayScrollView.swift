//
//  NotDelayScrollView.swift
//  Tonkeeper
//
//  Created by Grigory on 5.6.23..
//

import UIKit

final class NotDelayScrollView: UIScrollView {
  override init(frame: CGRect) {
    super.init(frame: frame)
    delaysContentTouches = false
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func touchesShouldCancel(in view: UIView) -> Bool {
    guard !(view is UIControl) else { return true }
    return super.touchesShouldCancel(in: view)
  }
}
