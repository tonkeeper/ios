import UIKit
import TKUIKit

final class ChooseWalletToAddCollectionController: NSObject {
  enum Section: Hashable {
    case wallets([Item])
  }
  
  typealias Item = ChooseWalletToAddCell.Model
  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
  
  typealias CellRegistration = UICollectionView.CellRegistration
  <ChooseWalletToAddCell, ChooseWalletToAddCell.Model>
  typealias HeaderRegistration = UICollectionView.SupplementaryRegistration
  <CollectionViewSupplementaryContainerView>
  
  var didSelect: ((IndexPath) -> Void)?
  var didDeselect: ((IndexPath) -> Void)?
  
  private let collectionView: UICollectionView
  private let headerViewProvider: (() -> UIView)?
  
  private let dataSource: DataSource
  private let cellRegistration: CellRegistration
  private let headerRegistration: HeaderRegistration
  
  init(collectionView: UICollectionView,
       headerViewProvider: (() -> UIView)? = nil) {
    self.collectionView = collectionView
    self.headerViewProvider = headerViewProvider
    
    let cellRegistration = CellRegistration { cell, indexPath, itemIdentifier in
      cell.configure(model: itemIdentifier)
    }
    self.cellRegistration = cellRegistration
    
    let headerRegistration = HeaderRegistration(elementKind: TKCollectionSupplementaryItem.header.rawValue) {
      supplementaryView, elementKind, indexPath in
      supplementaryView.setContentView(headerViewProvider?())
    }
    self.headerRegistration = headerRegistration
    
    self.dataSource = DataSource(collectionView: collectionView, cellProvider: { collectionView, indexPath, itemIdentifier in
      let cell = collectionView.dequeueConfiguredReusableCell(
        using: cellRegistration,
        for: indexPath,
        item: itemIdentifier)
      cell.isFirstInSection = { $0.item == 0 }
      cell.isLastInSection = { [unowned collectionView] in
        let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
        return $0.item == numberOfItems - 1
      }
      return cell
    })
    super.init()
    setupCollectionView()
    
    self.dataSource.supplementaryViewProvider = { collectionView, elementKind, indexPath in
      switch TKCollectionSupplementaryItem(rawValue: elementKind) {
      case .header:
        return collectionView.dequeueConfiguredReusableSupplementary(
          using: headerRegistration,
          for: indexPath
        )
      default:
        return nil
      }
    }
  }
  
  func setSections(_ sections: [Section]) {
    var snapshot = dataSource.snapshot()
    snapshot.deleteAllItems()
    
    sections.forEach { section in
      snapshot.appendSections([section])
      switch section {
      case .wallets(let items):
        snapshot.appendItems(items, toSection: section)
      }
    }
    dataSource.apply(snapshot, animatingDifferences: false)
  }
}

private extension ChooseWalletToAddCollectionController {
  func setupCollectionView() {
    setupLayout()
    collectionView.allowsMultipleSelection = true
    collectionView.delegate = self
  }
  
  func setupLayout() {
    collectionView.setCollectionViewLayout(
      ChooseWalletToAddLayout.createLayout(),
      animated: false
    )
  }
}

extension ChooseWalletToAddCollectionController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    didSelect?(indexPath)
  }
  
  func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
    didDeselect?(indexPath)
  }
}
