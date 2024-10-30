import UIKit.UICollectionView

public extension UICollectionView {

  func registerCellClass(_ cellClass: AnyClass) {
    register(cellClass, forCellWithReuseIdentifier: String(describing: cellClass))
  }

  func registerHeaderViewClass(_ viewClass: AnyClass) {
    register(viewClass, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
             withReuseIdentifier: String(describing: viewClass) + ".Header")
  }

  func registerFooterViewClass(_ viewClass: AnyClass) {
    register(viewClass, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
             withReuseIdentifier: String(describing: viewClass) + ".Footer")
  }

  func dequeueReusableCell<T: UICollectionViewCell>(for indexPath: IndexPath) -> T {
    guard let cell = dequeueReusableCell(withReuseIdentifier: String(describing: T.self), for: indexPath) as? T else {
      fatalError("Unable to dequeue reusable cell for indexPath: \((indexPath.section, indexPath.item))")
    }
    return cell
  }

  func dequeueReusableHeaderView<T: UICollectionReusableView>(for indexPath: IndexPath) -> T {
    guard let view = dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader,
                                                      withReuseIdentifier: String(describing: T.self) + ".Header",
                                                      for: indexPath) as? T else {
      fatalError("Unable to dequeue reusable header for indexPath: \((indexPath.section, indexPath.item))")
    }
    return view
  }

  func dequeueReusableFooterView<T: UICollectionReusableView>(for indexPath: IndexPath) -> T {
    guard let view = dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter,
                                                      withReuseIdentifier: String(describing: T.self) + ".Footer",
                                                      for: indexPath) as? T else {
      fatalError("Unable to dequeue reusable footer for indexPath: \((indexPath.section, indexPath.item))")
    }
    return view
  }
}
