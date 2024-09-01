import UIKit

public typealias ListItemCellRegistration = UICollectionView.CellRegistration<TKListItemCell, TKListItemCell.Configuration>
public extension ListItemCellRegistration {
  static func registration(collectionView: UICollectionView) -> ListItemCellRegistration {
    ListItemCellRegistration { cell, indexPath, configuration in
      cell.configuration = configuration
      cell.isFirstInSection = { ip in ip.item == 0 }
      cell.isLastInSection = { [weak collectionView] ip in
        guard let collectionView = collectionView else { return false }
        return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
      }
    }
  }
}
