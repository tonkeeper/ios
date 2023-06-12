//
//  DimmingTransitioningDelegate.swift
//  Tonkeeper
//
//  Created by Grigory on 8.6.23..
//

import UIKit

final class DimmingTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
  func presentationController(forPresented presented: UIViewController,
                              presenting: UIViewController?,
                              source: UIViewController) -> UIPresentationController? {
    return DimmingPresentationController(presentedViewController: presented, presenting: presenting)
  }
}
