//
//  TKMenuController.swift
//  Tonkeeper
//
//  Created by Grigory on 10.7.23..
//

import UIKit

final class TKMenuController {
  
  private static var window: UIWindow?
  private static var menuViewController: TKMenuViewController?
  private static weak var sourceView: UIView?
  
  static func show(sourceView: UIView,
                   items: [TKMenuItem],
                   selectionClosure: @escaping (Int) -> Void) {
    self.sourceView = sourceView
    guard let sourceWindow = sourceView.window else { return }
    
    let sourceViewConvertedFrame = sourceWindow.convert(sourceView.frame, from: sourceView.superview)
    let origin = CGPoint(x: sourceViewConvertedFrame.midX - .menuWidth/2,
                         y: sourceViewConvertedFrame.maxY + 10)
    
    let menuViewController = TKMenuViewController(items: items,
                                                  origin: origin,
                                                  menuWidth: .menuWidth)
    menuViewController.didSelectItem = { index in
      self.dismiss()
      selectionClosure(index)
    }
    
    menuViewController.didTapToDismiss = {
      self.dismiss()
    }

    sourceWindow.addSubview(menuViewController.view)
    menuViewController.view.frame = sourceWindow.bounds
    
    menuViewController.showMenu(duration: .animationDuration)
    
    self.menuViewController = menuViewController
  }
  
  static func dismiss() {
    menuViewController?.hideMenu(duration: .animationDuration, completion: {
      menuViewController?.view.removeFromSuperview()
      self.menuViewController = nil
    })
  }
}

private extension CGFloat {
  static let menuWidth: CGFloat = 220
}

private extension TimeInterval {
  static let animationDuration: TimeInterval = 0.4
}
