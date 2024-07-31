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
  
  public enum Title {
    case title(title: String, subtitle: NSAttributedString?)
    case customView(UIView)
    
    static func title(_ title: String, subtitle: String?) -> Title {
      return .title(
        title: title,
        subtitle: subtitle?.withTextStyle(
          .body2,
          color: .Text.secondary,
          alignment: .left
        )
      )
    }
  }
  
  let title: Title
  let leftButton: LeftButton?
  
  public init(title: Title,
              leftButton: LeftButton? = nil) {
    self.title = title
    self.leftButton = leftButton
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

