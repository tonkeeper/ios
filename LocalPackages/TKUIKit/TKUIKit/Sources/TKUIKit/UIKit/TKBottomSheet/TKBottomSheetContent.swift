import UIKit

public struct TKPullCardHeaderItem {
  public struct LeftButton {
    let model: TKUIHeaderTitleIconButton.Model
    let action: (() -> Void)
    
    public init(model: TKUIHeaderTitleIconButton.Model, action: @escaping (() -> Void)) {
      self.model = model
      self.action = action
    }
  }
  
  let title: String
  let subtitle: NSAttributedString?
  let leftButton: LeftButton?
  
  public init(title: String,
              subtitle: NSAttributedString? = nil,
              leftButton: LeftButton? = nil) {
    self.title = title
    self.subtitle = subtitle
    self.leftButton = leftButton
  }
  
  public init(title: String,
              subtitle: String?,
              leftButton: LeftButton? = nil) {
    let attributedSubtitle = subtitle?.withTextStyle(.body2, color: .Text.secondary, alignment: .left)
    self.init(title: title,
              subtitle: attributedSubtitle,
              leftButton: leftButton)
  }
}


public protocol TKBottomSheetContentViewController: UIViewController {
  var didUpdateHeight: (() -> Void)? { get set }
  
  var headerItem: TKPullCardHeaderItem? { get }
  var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)? { get set }
  func calculateHeight(withWidth width: CGFloat) -> CGFloat
}

public protocol TKBottomSheetScrollContentViewController: TKBottomSheetContentViewController {
  var scrollView: UIScrollView { get }
}

