import UIKit

public protocol ReusableView: UIView {
  static var reuseIdentifier: String { get }
  func prepareForReuse()
}

public extension ReusableView {
  static var reuseIdentifier: String {
    String(describing: Self.self)
  }
  
  func prepareForReuse() {}
}
