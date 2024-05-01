import UIKit

public protocol TKPullableCardContent: UIViewController {
  var title: String? { get }
  var height: CGFloat { get }
  var didUpdateHeight: (() -> Void)? { get set }
}

public protocol TKPullableCardScrollableContent: TKPullableCardContent {
  var scrollView: UIScrollView { get }
}
