import Foundation

public protocol CoordinatorDeeplink {
  var string: String { get }
}

extension String: CoordinatorDeeplink {
  public var string: String { self }
}
