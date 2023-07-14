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

extension NavigationController: UIGestureRecognizerDelegate {}
