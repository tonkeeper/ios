import UIKit

public extension TKUINavigationBar {
  static func createBackButton(action: @escaping () -> Void) -> UIView {
    let button = TKUIHeaderIconButton()
    button.configure(
      model: TKUIHeaderButtonIconContentView.Model(
        image: .TKUIKit.Icons.Size16.chevronLeft
      )
    )
    
    button.addTapAction(action)
    
    button.tapAreaInsets = UIEdgeInsets(
      top: -10,
      left: -10,
      bottom: -10,
      right: -10
    )
    return button
  }
  
  static func createSwipeDownButton(action: @escaping () -> Void) -> UIView {
    let button = TKUIHeaderIconButton()
    button.configure(
      model: TKUIHeaderButtonIconContentView.Model(
        image: .TKUIKit.Icons.Size16.chevronDown
      )
    )
    
    button.addTapAction(action)
    
    button.tapAreaInsets = UIEdgeInsets(
      top: -10,
      left: -10,
      bottom: -10,
      right: -10)
    return button
  }
  
  static func createMoreButton(action: @escaping () -> Void) -> UIView {
    let button = TKUIHeaderIconButton()
    button.configure(
      model: TKUIHeaderButtonIconContentView.Model(
        image: .TKUIKit.Icons.Size16.ellipses
      )
    )
    
    button.addTapAction(action)

    button.tapAreaInsets = UIEdgeInsets(
      top: -10,
      left: -10,
      bottom: -10,
      right: -10)
    return button
  }
}
