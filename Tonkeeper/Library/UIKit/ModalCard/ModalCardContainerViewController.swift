//
//  ModalCardContainerViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 8.6.23..
//

import UIKit

final class ModalCardContainerViewController: UIViewController {
  override var transitioningDelegate: UIViewControllerTransitioningDelegate? {
    get { dimmingTransitioningDelegate }
    set {}
  }
  
  override var modalPresentationStyle: UIModalPresentationStyle {
    get { .custom }
    set {}
  }
  
  private let dimmingTransitioningDelegate = DimmingTransitioningDelegate()
  
  override func loadView() {
    view = PassthroughView()
  }
}
