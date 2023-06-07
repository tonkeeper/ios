//
//  ActivityListCollectionController.swift
//  Tonkeeper
//
//  Created by Grigory on 6.6.23..
//

import UIKit

final class ActivityListCollectionController {
  
  var sections = [ActivityListSection]() {
    didSet {
      didUpdateSections()
    }
  }
  
  private weak var collectionView: UICollectionView?
  private var dataSource: UICollectionViewDiffableDataSource<ActivityListSection, AnyHashable>?
  
  private let collectionLayoutConfigurator = ActivityListCollectionLayoutConfigurator()
  
  init(collectionView: UICollectionView) {
    self.collectionView = collectionView
    let layout = collectionLayoutConfigurator.getLayout()
    collectionView.setCollectionViewLayout(layout, animated: false)
    collectionView.register(ActivityListTransactionCell.self,
                             forCellWithReuseIdentifier: ActivityListTransactionCell.reuseIdentifier)
    dataSource = createDataSource(collectionView: collectionView)
  }
}

private extension ActivityListCollectionController {
  func didUpdateSections() {
    var snapshot = NSDiffableDataSourceSnapshot<ActivityListSection, AnyHashable>()
    sections.forEach { section in
      snapshot.appendSections([section])
      snapshot.appendItems(section.items, toSection: section)
    }
    dataSource?.apply(snapshot)
  }
  
  func createDataSource(collectionView: UICollectionView) -> UICollectionViewDiffableDataSource<ActivityListSection, AnyHashable> {
    .init(collectionView: collectionView) { [weak self] collectionView, indexPath, itemIdentifier in
      guard let self = self else { return UICollectionViewCell() }
      switch itemIdentifier {
      case let model as ActivityListTransactionCell.Model:
        return self.getTransactionCell(collectionView: collectionView,
                                       indexPath: indexPath,
                                       model: model)
      default:
        return UICollectionViewCell()
      }
    }
  }
  
  func getTransactionCell(collectionView: UICollectionView,
                          indexPath: IndexPath,
                          model: ActivityListTransactionCell.Model) -> UICollectionViewCell {
    guard let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: ActivityListTransactionCell.reuseIdentifier,
      for: indexPath) as? ActivityListTransactionCell else {
      return UICollectionViewCell()
    }
    
    cell.configure(model: model)
    cell.isFirstCell = indexPath.item == 0
    cell.isLastCell = indexPath.item == sections[indexPath.section].items.count - 1
    return cell
  }
}
