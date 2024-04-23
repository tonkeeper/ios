import UIKit
import TKUIKit

final class WalletsListCollectionController: TKCollectionController<WalletsListSection, AnyHashable> {
  
  typealias WalletCellRegistration = UICollectionView.CellRegistration<WalletsListWalletCell, WalletsListWalletCell.Model>
  
  private let walletCellRegistration: WalletCellRegistration
  
  init(collectionView: UICollectionView,
       footerViewProvider: (() -> UIView)? = nil) {
    let walletCellRegistration = WalletCellRegistration { cell, indexPath, itemIdentifier in
      cell.configure(model: itemIdentifier)
    }
    self.walletCellRegistration = walletCellRegistration
    
    super.init(
      collectionView: collectionView, cellProvider: { collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let model as WalletsListWalletCell.Model:
          let cell = collectionView.dequeueConfiguredReusableCell(using: walletCellRegistration, for: indexPath, item: model)
          cell.isFirstInSection = { return $0.item == 0 }
          cell.isLastInSection = { [unowned collectionView] in
            let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
            return $0.item == numberOfItems - 1
          }
          return cell
        default: return nil
        }
      },
      footerViewProvider: footerViewProvider)
    
    collectionView.setCollectionViewLayout(TKCollectionLayout.layout(sectionLayout: { [weak self] sectionIndex in
      guard let self = self else { return nil }
      let section = dataSource.snapshot().sectionIdentifiers[sectionIndex]
      switch section {
      case .wallets:
        return TKCollectionLayout.listSectionLayout(
          padding: NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16),
          heightDimension: .absolute(76))
      }
    }), animated: false)
  }
  
  func setWallets(_ wallets: [WalletsListWalletCell.Model]) {
    var snapshot = dataSource.snapshot()
    snapshot.deleteSections([.wallets])
    snapshot.appendSections([.wallets])
    snapshot.appendItems(wallets, toSection: .wallets)
    snapshot.reloadSections([.wallets])
    UIView.performWithoutAnimation {
      dataSource.apply(snapshot, animatingDifferences: false)
    }
  }
}
