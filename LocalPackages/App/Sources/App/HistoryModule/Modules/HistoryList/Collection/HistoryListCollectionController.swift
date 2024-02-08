import UIKit
import TKUIKit

final class HistoryListCollectionController: NSObject {
  typealias DataSource = UICollectionViewDiffableDataSource<HistoryListSection, AnyHashable>
  
  typealias HistoryCellRegistration = UICollectionView.CellRegistration<HistoryEventCell, HistoryEventCell.Model>
  
  var loadNextPage: (() -> Void)?
  
  private let collectionView: UICollectionView
  private let dataSource: DataSource
  private let historyCellRegistration: HistoryCellRegistration
  
  init(collectionView: UICollectionView) {
    self.collectionView = collectionView
    
    let historyCellRegistration = HistoryCellRegistration(handler: { cell, indexPath, itemIdentifier in
      cell.configure(model: itemIdentifier)
    })
    
    let dataSource = DataSource(
      collectionView: collectionView,
      cellProvider: { collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let model as HistoryEventCell.Model:
          return collectionView.dequeueConfiguredReusableCell(
            using: historyCellRegistration,
            for: indexPath,
            item: model)
        default:
          return nil
        }
      }
    )
    self.dataSource = dataSource
    self.historyCellRegistration = historyCellRegistration
    
    super.init()
    
    let layout = HistoryListCollectionLayout.layout { sectionIndex in
      return dataSource.snapshot().sectionIdentifiers[sectionIndex]
    }
    
    collectionView.setCollectionViewLayout(layout, animated: false)
    
    collectionView.delegate = self
  }
  
  func setSections(_ sections: [HistoryListSection]) {
    var snapshot = dataSource.snapshot()
    snapshot.deleteAllItems()
    snapshot.appendSections(sections)
    for section in sections {
      switch section {
      case .events(let sectionModel):
        snapshot.appendItems(sectionModel.events, toSection: section)
      }
    }
    UIView.performWithoutAnimation {
      dataSource.apply(snapshot)
    }
  }
}

private extension HistoryListCollectionController {
  func fetchNextIfNeeded(collectionView: UICollectionView, indexPath: IndexPath) {
    let numberOfSections = collectionView.numberOfSections
    let numberOfItems = collectionView.numberOfItems(inSection: numberOfSections - 1)
    guard (indexPath.section == numberOfSections - 1) && (indexPath.item == numberOfItems - 1) else { return }
    loadNextPage?()
  }
}

extension HistoryListCollectionController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, 
                      willDisplay cell: UICollectionViewCell,
                      forItemAt indexPath: IndexPath) {
    fetchNextIfNeeded(collectionView: collectionView, indexPath: indexPath)
  }
}
