//
//  BuyListCollectionController.swift
//  Tonkeeper
//
//  Created by Grigory on 9.6.23..
//

import UIKit

protocol BuyListCollectionControllerDelegate: AnyObject {
  func buyListCollectionController(_ collectionController: BuyListCollectionController,
                                   didSelectServiceAt indexPath: IndexPath)
}

final class BuyListCollectionController: NSObject {
  
  var sections = [BuyListSection]() {
    didSet {
      didUpdateSections()
    }
  }
  
  weak var delegate: BuyListCollectionControllerDelegate?
  
  private weak var collectionView: UICollectionView?
  private var dataSource: UICollectionViewDiffableDataSource<BuyListSection, AnyHashable>?
  
  private let collectionLayoutConfigurator = BuyListCollectionLayoutConfigurator()
  
  init(collectionView: UICollectionView) {
    self.collectionView = collectionView
    super.init()
    let layout = collectionLayoutConfigurator.getLayout { [weak self] sectionIndex in
      guard let self = self else { return .services }
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

private extension BuyListCollectionController {
  func didUpdateSections() {
    var snapshot = NSDiffableDataSourceSnapshot<BuyListSection, AnyHashable>()
    sections.forEach { section in
      snapshot.appendSections([section])
      snapshot.appendItems(section.items, toSection: section)
    }
    dataSource?.apply(snapshot)
  }
  
  func createDataSource(collectionView: UICollectionView) -> UICollectionViewDiffableDataSource<BuyListSection, AnyHashable> {
    .init(collectionView: collectionView) { [weak self] collectionView, indexPath, itemIdentifier in
      guard let self = self else { return UICollectionViewCell() }
      switch itemIdentifier {
      default:
        return UICollectionViewCell()
      }
    }
  }
  
  func getServiceCell(collectionView: UICollectionView,
                      indexPath: IndexPath) -> UICollectionViewCell {
    return UICollectionViewCell()
  }
  
  func getButtonCell(collectionView: UICollectionView,
                     indexPath: IndexPath) -> UICollectionViewCell {
    
    return UICollectionViewCell()
  }
}

extension BuyListCollectionController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    (collectionView.cellForItem(at: indexPath) as? Selectable)?.select()
    collectionView.deselectItem(at: indexPath, animated: true)
    delegate?.buyListCollectionController(self,
                                          didSelectServiceAt: indexPath)
  }
  
  func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
    (collectionView.cellForItem(at: indexPath) as? Selectable)?.deselect()
  }
}

