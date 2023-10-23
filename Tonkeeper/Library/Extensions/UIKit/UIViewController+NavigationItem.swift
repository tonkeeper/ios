//
//  UIViewController+NavigationItem.swift
//  Tonkeeper
//
//  Created by Grigory on 31.5.23..
//

import UIKit

extension UIViewController {
  func setupCloseLeftButton(closure: @escaping () -> Void) {
    navigationItem.leftBarButtonItem = createCloseButton(closure: closure)
  }
  
  func setupCloseRightButton(closure: @escaping () -> Void) {
    navigationItem.rightBarButtonItem = createCloseButton(closure: closure)
  }
  
  func setupBackButton() {
    let swipeButton = TKButton(configuration: .Header.button)
    swipeButton.tapAreaInsets = .tapAreaInsets
    swipeButton.configure(model: .init(icon: .Icons.Buttons.Header.back))
    swipeButton.addAction(.init(handler: { [weak self] in
      self?.navigationController?.popViewController(animated: true)
    }), for: .touchUpInside)
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: swipeButton)
  }
  
  func setupSwipeButton(closure: @escaping () -> Void) {
    let swipeButton = TKButton(configuration: .Header.button)
    swipeButton.tapAreaInsets = .tapAreaInsets
    swipeButton.configure(model: .init(icon: .Icons.Buttons.Header.swipe))
    swipeButton.addAction(.init(handler: {
      closure()
    }), for: .touchUpInside)
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: swipeButton)
  }
}

private extension UIViewController {
  func createCloseButton(closure: @escaping () -> Void) -> UIBarButtonItem {
    let button = TKButton(configuration: .Header.button)
    button.tapAreaInsets = .tapAreaInsets
    button.configure(model: .init(icon: .Icons.Buttons.Header.close))
    button.addAction(.init(handler: {
      closure()
    }), for: .touchUpInside)
    return UIBarButtonItem(customView: button)
  }
}

private extension NSDirectionalEdgeInsets {
  static var tapAreaInsets: NSDirectionalEdgeInsets {
    .init(top: 12, leading: 12, bottom: 12, trailing: 12)
  }
}
