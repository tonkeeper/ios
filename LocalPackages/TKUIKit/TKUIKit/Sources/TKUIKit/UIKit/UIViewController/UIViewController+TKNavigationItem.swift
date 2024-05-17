import UIKit

public extension UIViewController {
  func setupBackButton() {
    navigationItem.setupBackButton { [weak self] in
      self?.navigationController?.popViewController(animated: true)
    }
  }
  
  func setupSwipeDownButton() {
    navigationItem.setupSwipeDown { [weak self] in
      self?.dismiss(animated: true)
    }
  }
  
  func setupSwipeDownButton(_ action: @escaping () -> Void) {
    navigationItem.setupSwipeDown {
      action()
    }
  }
  
  func setupLeftCloseButton(_ action: @escaping () -> Void) {
    let closeButton = createCloseButton(action)
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: closeButton)
  }
  
  func setupRightCloseButton(_ action: @escaping () -> Void) {
    let closeButton = createCloseButton(action)
    navigationItem.rightBarButtonItem = UIBarButtonItem(customView: closeButton)
  }
  
  func createCloseButton(_ action: @escaping () -> Void) -> TKUIHeaderIconButton {
    let closeButton = TKUIHeaderIconButton()
    closeButton.configure(
      model: TKUIHeaderButtonIconContentView.Model(
        image: .TKUIKit.Icons.Size16.close
      )
    )
    closeButton.addTapAction {
      action()
    }
    closeButton.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
    return closeButton
  }
  
  func createButton(icon: UIImage, _ action: @escaping () -> Void) -> TKUIHeaderIconButton {
    let button = TKUIHeaderIconButton()
    button.configure(
      model: TKUIHeaderButtonIconContentView.Model(
        image: icon
      )
    )
    button.addTapAction {
      action()
    }
    button.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
    return button
  }
  
  func setupButton(icon: UIImage, position: UINavigationItem.Position = .left,  _ action: @escaping (() -> Void)) {
    let button = createButton(icon: icon, action)
    let buttonItem = UIBarButtonItem(customView: button)
    
    switch position {
    case .left:
      navigationItem.leftBarButtonItem = buttonItem
    case .right:
      navigationItem.rightBarButtonItem = buttonItem
    }
  }
}

public extension UINavigationItem {
  enum Position {
    case left, right
  }
}

public extension UINavigationItem {
  func setupBackButton(action: @escaping () -> Void) {
    let backButton = TKUIHeaderIconButton()
    backButton.configure(
      model: TKUIHeaderButtonIconContentView.Model(
        image: .TKUIKit.Icons.Size16.chevronLeft
      )
    )
    
    backButton.addTapAction(action)
    
    backButton.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
    leftBarButtonItem = UIBarButtonItem(customView: backButton)
  }
  
  func setupSwipeDown(action: @escaping () -> Void) {
    let backButton = TKUIHeaderIconButton()
    backButton.configure(
      model: TKUIHeaderButtonIconContentView.Model(
        image: .TKUIKit.Icons.Size16.chevronDown
      )
    )
    
    backButton.addTapAction(action)
    
    backButton.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
    leftBarButtonItem = UIBarButtonItem(customView: backButton)
  }
}
