import UIKit

extension UIImage {
  static func imageWithName(_ name: String) -> UIImage? {
    return UIImage(named: name, in: .module, with: nil)
  }
}
