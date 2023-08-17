//
//  NavigationController.swift
//  Tonkeeper
//
//  Created by Grigory on 31.5.23..
//

import UIKit

final class NavigationController: UINavigationController {
  override func viewDidLoad() {
    super.viewDidLoad()
    interactivePopGestureRecognizer?.delegate = self
  }
}

extension NavigationController: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let view = gestureRecognizer.view,
          let otherView = otherGestureRecognizer.view else { return false }
    
    guard otherView.next is NavigationController,
            otherView.isDescendant(of: view) else {
      return true
    }
    return false
  }
}
