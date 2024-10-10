import UIKit

public enum TKPopupMenuPosition {
  case topRight
  case bottomRight(inset: CGFloat)
}

public final class TKPopupMenuController {
  
  private static var window: UIWindow?
  private static var menuViewController: TKPopupMenuViewController?
  private static weak var sourceView: UIView?
  
  public static func show(sourceView: UIView,
                          position: TKPopupMenuPosition,
                          width: CGFloat,
                          items: [TKPopupMenuItem],
                          isSelectable: Bool = true,
                          selectedIndex: Int?) {
    self.sourceView = sourceView
    guard let sourceWindow = sourceView.window else { return }
    
    let menuViewController = TKPopupMenuViewController()
    menuViewController.didSelectItem = { 
      self.dismiss()
    }

    menuViewController.didTapToDismiss = {
      self.dismiss()
    }
    
    sourceWindow.addSubview(menuViewController.view)
    menuViewController.view.frame = sourceWindow.bounds
    
    menuViewController.showMenu(
      items: items,
      selectedIndex: selectedIndex,
      sourceView: sourceView,
      position: position,
      maximumWidth: .menuWidth,
      isSelectable: isSelectable,
      duration: .animationDuration
    )
    
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
  static let animationDuration: TimeInterval = 0.3
}
