import UIKit

protocol TokenDetailsListContentViewController: UIViewController {
  var scrollView: UIScrollView { get }
  func setHeaderViewController(_ headerViewController: UIViewController?)
}
