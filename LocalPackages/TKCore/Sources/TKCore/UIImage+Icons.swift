import UIKit

public extension UIImage {
  enum TKCore {
    public enum Icons {
      public enum Size44 {
        public static var tonLogo: UIImage {
          .imageWithName("Icons/Size44/ton_logo")
        }
      }
    }
  }
}

private extension UIImage {
  static func imageWithName(_ name: String) -> UIImage {
    return UIImage(named: name, in: .module, with: nil) ?? UIImage()
  }
}
