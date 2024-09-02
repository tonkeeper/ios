import UIKit

public typealias TKButtonCollectionViewCellRegistration = UICollectionView.CellRegistration<TKButtonCollectionViewCell, TKButtonCollectionViewCell.Configuration>
public extension TKButtonCollectionViewCellRegistration {
  static func registration() -> TKButtonCollectionViewCellRegistration {
    TKButtonCollectionViewCellRegistration { cell, indexPath, configuration in
      cell.configuration = configuration
    }
  }
}
