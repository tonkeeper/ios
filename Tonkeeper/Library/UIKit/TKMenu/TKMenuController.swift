//
//  TKMenuController.swift
//  Tonkeeper
//
//  Created by Grigory on 10.7.23..
//

import UIKit

final class TKMenuController {
  
  enum Position {
    case center
    case right
  }
  
  private static var window: UIWindow?
  private static var menuViewController: TKMenuViewController?
  private static weak var sourceView: UIView?
  
  static func show(sourceView: UIView,
                   position: Position,
                   width: CGFloat,
                   items: [TKMenuItem],
                   selectionClosure: @escaping (Int) -> Void) {
    self.sourceView = sourceView
    guard let sourceWindow = sourceView.window else { return }
    
    let origin = calculateOrigin(
      sourceView: sourceView,
      sourceWindow: sourceWindow,
      position: position
    )
    
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

private extension TKMenuController {
  static func calculateOrigin(sourceView: UIView,
                              sourceWindow: UIWindow,
                              position: Position) -> CGPoint {
    let sourceViewConvertedFrame = sourceWindow.convert(sourceView.frame,
                                                        from: sourceView.superview)
    let origin: CGPoint
    switch position {
    case .center:
      origin = CGPoint(x: sourceViewConvertedFrame.midX - .menuWidth/2,
                       y: sourceViewConvertedFrame.maxY + 10)
    case .right:
      origin = CGPoint(x: sourceViewConvertedFrame.maxX - .menuWidth,
                       y:  sourceViewConvertedFrame.maxY + 10)
    }
    return origin
  }
}

private extension CGFloat {
  static let menuWidth: CGFloat = 220
}

private extension TimeInterval {
  static let animationDuration: TimeInterval = 0.3
}
