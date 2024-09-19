import UIKit

final class TKPopupMenuViewController: UIViewController {
  
  var didTapToDismiss: (() -> Void)?
  var didSelectItem: (() -> Void)?
  
  private let menuView = TKPopupMenuView()
  private let dismissView = UIView()

  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.backgroundColor = .clear
    view.addSubview(dismissView)
    view.addSubview(menuView)
    
    menuView.didSelectItem = { [weak self] in
      self?.didSelectItem?()
    }

    let dismissGesture = UITapGestureRecognizer(
      target: self,
      action: #selector(didTap)
    )
    dismissView.addGestureRecognizer(dismissGesture)
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    dismissView.frame = view.bounds
  }
  
  func showMenu(items: [TKPopupMenuItem], 
                selectedIndex: Int?,
                sourceView: UIView,
                position: TKPopupMenuPosition,
                maximumWidth: CGFloat,
                isSelectable: Bool = true,
                duration: TimeInterval) {
    let menuViewItems = items.map { item in
      TKPopupMenuItemView.Model(
        title: item.title,
        value: item.value,
        description: item.description,
        icon: item.icon,
        isSelectable: isSelectable,
        selectionHandler: item.selectionHandler
      )
    }
    
    menuView.items = menuViewItems
    if let selectedIndex { menuView.selectItem(index: selectedIndex) }
    
    let menuSize = menuView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    
    let sourceViewFrame = self.view.window?.convert(sourceView.frame, from: sourceView.superview) ?? .zero
    let origin: CGPoint
    
    switch position {
    case .topRight:
      origin = CGPoint(x: sourceViewFrame.maxX - menuSize.width,
                       y: sourceViewFrame.minY)
    }

    let frame = CGRect(origin: origin, size: menuSize)
    
    let initialTransformation = CGAffineTransform(scaleX: 0.9, y: 0.9)
    let finalTransformation = CGAffineTransform(scaleX: 1, y: 1)
    
    menuView.frame = frame
    menuView.alpha = .hideAlpha
    menuView.transform = initialTransformation
    
    UIView.animate(withDuration: duration,
                   delay: 0,
                   usingSpringWithDamping: 2,
                   initialSpringVelocity: 0.5,
                   options: [.curveEaseInOut, .allowUserInteraction]) {
      self.menuView.transform = finalTransformation
      self.menuView.alpha = 1
    }
  }

  func hideMenu(duration: TimeInterval, completion: @escaping () -> Void) {
    let finalTransform = CGAffineTransform(scaleX: 0.9, y: 0.9)
    UIView.animate(withDuration: duration,
                   delay: 0,
                   usingSpringWithDamping: 2,
                   initialSpringVelocity: 0.5,
                   options: [.curveEaseInOut, .allowUserInteraction]) {
      self.menuView.transform = finalTransform
      self.menuView.alpha = 0
    } completion: { _ in
      completion()
    }
  }
  
  @objc
  private func didTap() {
    didTapToDismiss?()
  }
}

private extension CGFloat {
  static let menuItemHeight: CGFloat = 48
  static let heightCoeff: CGFloat = 4.5
  static let cornerRadius: CGFloat = 16
  static let hideAlpha: CGFloat = 0.3
}

private extension Int {
  static let maximumRows = 4
}
