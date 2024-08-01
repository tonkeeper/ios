import UIKit

protocol TokenDetailsListContentViewController: UIViewController {
  var scrollView: UIScrollView { get }
  func setHeaderViewController(_ headerViewController: UIViewController?)
}

extension HistoryV2ListViewController: TokenDetailsListContentViewController {
  var scrollView: UIScrollView {
    customView.collectionView
  }
}
