import UIKit

public extension TKPopUp {
  protocol Item {
    var bottomSpace: CGFloat { get }
    func getView() -> UIView
  }
}
