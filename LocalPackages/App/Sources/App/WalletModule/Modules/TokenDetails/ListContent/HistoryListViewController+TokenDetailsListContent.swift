import UIKit

extension HistoryListViewController: TokenDetailsListContentViewController {
  var scrollView: UIScrollView {
    customView.collectionView
  }
}
