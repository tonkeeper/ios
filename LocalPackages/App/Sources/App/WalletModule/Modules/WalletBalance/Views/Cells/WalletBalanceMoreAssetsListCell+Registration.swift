import UIKit

public typealias WalletBalanceMoreAssetsListCellRegistration = UICollectionView.CellRegistration<
    WalletBalanceMoreAssetsListCell,
    Void
>

public extension WalletBalanceMoreAssetsListCellRegistration {
    static func registration(collectionView: UICollectionView) -> WalletBalanceMoreAssetsListCellRegistration {
        WalletBalanceMoreAssetsListCellRegistration { [collectionView] cell, _, _ in
            cell.isFirstInSection = { _ in false }
            cell.isLastInSection = { [weak collectionView] ip in
                guard let collectionView else { return false }
                return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
            }
        }
    }
}
