import UIKit
import TKUIKit

final class WalletBalanceCollectionController: TKCollectionController<WalletBalanceSection, AnyHashable> {
  
  typealias BalanceCellRegistration = UICollectionView.CellRegistration<WalletBalanceBalanceItemCell, WalletBalanceBalanceItemCell.Model>
  
  private let balanceCellRegistration: BalanceCellRegistration
  
  init(collectionView: UICollectionView,
       headerViewProvider: (() -> UIView)? = nil, footerViewProvider: (() -> UIView)? = nil) {
    let balanceCellRegistration = BalanceCellRegistration { cell, indexPath, itemIdentifier in
      cell.configure(model: itemIdentifier)
    }
    self.balanceCellRegistration = balanceCellRegistration
    
    super.init(
      collectionView: collectionView, cellProvider: { collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let model as WalletBalanceBalanceItemCell.Model:
          let cell = collectionView.dequeueConfiguredReusableCell(using: balanceCellRegistration, for: indexPath, item: model)
          cell.isFirstInSection = { return $0.item == 0 }
          cell.isLastInSection = { [unowned collectionView] in
            let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
            return $0.item == numberOfItems - 1
          }
          return cell
        default: return nil
        }
      },
      headerViewProvider: headerViewProvider)
    
    collectionView.setCollectionViewLayout(TKCollectionLayout.layout(sectionLayout: { [weak self] sectionIndex in
      guard let self = self else { return nil }
      let section = dataSource.snapshot().sectionIdentifiers[sectionIndex]
      switch section {
      case .balanceItems:
        return TKCollectionLayout.listSectionLayout(
          padding: NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16),
          heightDimension: .absolute(76))
      }
    }), animated: false)
    
    collectionView.contentInset.bottom = 16
  }
  
  func setBalanceItems(_ items: [AnyHashable]) {
    var snapshot = dataSource!.snapshot()
    snapshot.deleteSections([.balanceItems])
    snapshot.appendSections([.balanceItems])
    snapshot.appendItems(items, toSection: .balanceItems)
    snapshot.reloadSections([.balanceItems])
    UIView.performWithoutAnimation {
      dataSource?.apply(snapshot, animatingDifferences: true)
    }
  }
}
