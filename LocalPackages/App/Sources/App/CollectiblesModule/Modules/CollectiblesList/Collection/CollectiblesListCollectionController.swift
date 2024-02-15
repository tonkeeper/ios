import UIKit
import TKUIKit

final class CollectiblesListCollectionController: NSObject {
  typealias DataSource = UICollectionViewDiffableDataSource<CollectiblesListSection, CollectibleCollectionViewCell.Model>
  
  var loadNextPage: (() -> Void)?
  
  private let collectionView: UICollectionView
  private let dataSource: DataSource
  
  init(collectionView: UICollectionView) {
    self.collectionView = collectionView
    
    let dataSource = DataSource(
      collectionView: collectionView) {
        collectionView,
        indexPath,
        itemIdentifier in
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CollectibleCollectionViewCell.reuseIdentifier, for: indexPath) as? CollectibleCollectionViewCell
        cell?.configure(model: itemIdentifier)
        return cell
      }
    
    self.dataSource = dataSource
    
    super.init()
    
    let layout = CollectiblesListCollectionLayout.layout()
    collectionView.setCollectionViewLayout(layout, animated: false)
    
    collectionView.register(CollectibleCollectionViewCell.self, forCellWithReuseIdentifier: CollectibleCollectionViewCell.reuseIdentifier)
    
    collectionView.delegate = self
  }
  
  func setSections(_ sections: [CollectiblesListSection]) {
    var snapshot = dataSource.snapshot()
    snapshot.deleteAllItems()
    snapshot.appendSections(sections)
    for section in sections {
      switch section {
      case .collectibles(let items):
        snapshot.appendItems(items, toSection: section)
      }
    }
    UIView.performWithoutAnimation {
      dataSource.apply(snapshot)
    }
  }
}

private extension CollectiblesListCollectionController {
  func fetchNextIfNeeded(collectionView: UICollectionView, indexPath: IndexPath) {
    let numberOfSections = collectionView.numberOfSections
    let numberOfItems = collectionView.numberOfItems(inSection: numberOfSections - 1)
    guard (indexPath.section == numberOfSections - 1) && (indexPath.item == numberOfItems - 1) else { return }
    loadNextPage?()
  }
}

extension CollectiblesListCollectionController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView,
                      willDisplay cell: UICollectionViewCell,
                      forItemAt indexPath: IndexPath) {
    fetchNextIfNeeded(collectionView: collectionView, indexPath: indexPath)
  }
}
