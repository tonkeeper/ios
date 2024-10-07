import UIKit

extension PopUp {
  protocol Item {
    var bottomSpace: CGFloat { get }
    func getView() -> UIView
  }
}
