import UIKit

public protocol TKConfigurableView: UIView {
  associatedtype Configuration: Hashable
  
  func configure(configuration: Configuration)
}
