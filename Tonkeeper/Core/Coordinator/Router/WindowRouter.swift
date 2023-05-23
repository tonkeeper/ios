//
//  WindowRouter.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class WindowRouter: RouterProtocol {
  private let window: UIWindow
  
  init(window: UIWindow) {
    self.window = window
  }
  
  func setRoot(presentable: Presentable) {
    window.rootViewController = presentable.viewController
  }
}
