//
//  UIViewController+NavigationItem.swift
//  Tonkeeper
//
//  Created by Grigory on 31.5.23..
//

import UIKit

extension UIViewController {
  func setupCloseButton(closure: @escaping () -> Void) {
    let swipeButton = Button(configuration: .Header.button)
    swipeButton.configure(model: .init(icon: .Icons.Buttons.Header.close))
    swipeButton.addAction(.init(handler: {
      closure()
    }), for: .touchUpInside)
    navigationItem.rightBarButtonItem = UIBarButtonItem(customView: swipeButton)
  }
  
  func setupBackButton() {
    let swipeButton = Button(configuration: .Header.button)
    swipeButton.configure(model: .init(icon: .Icons.Buttons.Header.back))
    swipeButton.addAction(.init(handler: { [weak self] in
      self?.navigationController?.popViewController(animated: true)
    }), for: .touchUpInside)
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: swipeButton)
  }
}
