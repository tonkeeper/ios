import UIKit

public protocol ConfigurableView: UIView {
  associatedtype Model
  func configure(model: Model)
}
