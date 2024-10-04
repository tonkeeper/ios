import UIKit

public typealias WalletBalanceListCellRegistration = UICollectionView.CellRegistration<WalletBalanceListCell, WalletBalanceListCell.Configuration>
public extension WalletBalanceListCellRegistration {
  static func registration(collectionView: UICollectionView) -> WalletBalanceListCellRegistration {
    WalletBalanceListCellRegistration { cell, indexPath, configuration in
      cell.configuration = configuration
      cell.isFirstInSection = { ip in ip.item == 0 }
      cell.isLastInSection = { [weak collectionView] ip in
        guard let collectionView = collectionView else { return false }
        return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
      }
    }
  }
}
