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
