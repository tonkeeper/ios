import UIKit

extension UIImage {
  public static func imageWithName(_ name: String, bundle: Bundle) -> UIImage {
    return UIImage(named: name, in: bundle, with: nil) ?? UIImage()
  }
  
  static func imageWithName(_ name: String) -> UIImage {
    return UIImage(named: name, in: .module, with: nil) ?? UIImage()
  }
}
