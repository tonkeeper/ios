import UIKit

open class GenericViewViewController<View: UIView>: UIViewController {
  public var customView: View { self.view as! View }
  open override func loadView() {
    view = View()
  }
}
