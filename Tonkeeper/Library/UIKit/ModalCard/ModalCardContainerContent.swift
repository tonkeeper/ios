//
//  ModalCardContainerContent.swift
//  Tonkeeper
//
//  Created by Grigory on 8.6.23..
//

import UIKit

protocol ModalCardContainerContent: UIViewController {
  var title: String? { get }
  var height: CGFloat { get }
  var didUpdateHeight: (() -> Void)? { get set }
}

protocol ScrollableModalCardContainerContent: ModalCardContainerContent {
  var scrollView: UIScrollView { get }
}
