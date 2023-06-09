//
//  ActivityListCollectionController.swift
//  Tonkeeper
//
//  Created by Grigory on 6.6.23..
//

import UIKit

protocol ActivityListCollectionControllerDelegate: AnyObject {
  func activityListCollectionController(_ collectionController: ActivityListCollectionController,
                                        didSelectTransactionAt indexPath: IndexPath)
}

final class ActivityListCollectionController: NSObject {
  
  var sections = [ActivityListSection]() {
    didSet {
      didUpdateSections()
    }
  }
  
  weak var delegate: ActivityListCollectionControllerDelegate?
  
  private weak var collectionView: UICollectionView?
  private var dataSource: UICollectionViewDiffableDataSource<ActivityListSection, AnyHashable>?
  
  private let collectionLayoutConfigurator = ActivityListCollectionLayoutConfigurator()
  
  init(collectionView: UICollectionView) {
    self.collectionView = collectionView
    super.init()
    let layout = collectionLayoutConfigurator.getLayout { [weak self] sectionIndex in
      guard let self = self else { return .date }
      return self.sections[sectionIndex].type
    }
    collectionView.delegate = self
    collectionView.setCollectionViewLayout(layout, animated: false)
    collectionView.register(ActivityListTransactionCell.self,
                             forCellWithReuseIdentifier: ActivityListTransactionCell.reuseIdentifier)
    collectionView.register(ActivityListDateCell.self,
                            forCellWithReuseIdentifier: ActivityListDateCell.reuseIdentifier)
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
      case let model as ActivityListDateCell.Model:
        return self.getDateCell(collectionView: collectionView,
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
    cell.isInGroup = sections[indexPath.section].items.count > 1
    return cell
  }
  
  func getDateCell(collectionView: UICollectionView,
                          indexPath: IndexPath,
                          model: ActivityListDateCell.Model) -> UICollectionViewCell {
    guard let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: ActivityListDateCell.reuseIdentifier,
      for: indexPath) as? ActivityListDateCell else {
      return UICollectionViewCell()
    }
    
    cell.configure(model: model)
    return cell
  }
}

extension ActivityListCollectionController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    (collectionView.cellForItem(at: indexPath) as? Selectable)?.select()
    collectionView.deselectItem(at: indexPath, animated: true)
    delegate?.activityListCollectionController(self,
                                               didSelectTransactionAt: indexPath)
  }
  
  func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
    (collectionView.cellForItem(at: indexPath) as? Selectable)?.deselect()
  }
}
