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
    guard let sourceWindow = sourceView.window,
          let windowScene = sourceWindow.windowScene else { return }
    
    let menuWindow = UIWindow(windowScene: windowScene)
    menuWindow.backgroundColor = .clear
    menuWindow.makeKeyAndVisible()
    
    let sourceViewConvertedFrame = menuWindow.convert(sourceView.frame, from: sourceView.superview)
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
    
    menuWindow.rootViewController = menuViewController
    
    menuViewController.showMenu(duration: .animationDuration)
    
    self.window = menuWindow
    self.menuViewController = menuViewController
  }
  
  static func dismiss() {
    guard let sourceWindow = sourceView?.window else { return }
    menuViewController?.hideMenu(duration: .animationDuration, completion: {
      self.window = nil
      self.menuViewController = nil
      sourceWindow.makeKeyAndVisible()
    })
  }
}

private extension CGFloat {
  static let menuWidth: CGFloat = 220
}

private extension TimeInterval {
  static let animationDuration: TimeInterval = 0.5
}
