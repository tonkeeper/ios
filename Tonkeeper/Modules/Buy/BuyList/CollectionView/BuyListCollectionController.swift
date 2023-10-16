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
  private let imageLoader = NukeImageLoader()
  
  init(collectionView: UICollectionView) {
    self.collectionView = collectionView
    super.init()
    let layout = collectionLayoutConfigurator.getLayout { [weak self] sectionIndex in
      guard let self = self else { return .services }
      return self.sections[sectionIndex].type
    }
    collectionView.delegate = self
    collectionView.setCollectionViewLayout(layout, animated: false)
    collectionView.register(BuyListServiceCell.self,
                             forCellWithReuseIdentifier: BuyListServiceCell.reuseIdentifier)
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
    dataSource?.apply(snapshot, animatingDifferences: false)
  }
  
  func createDataSource(collectionView: UICollectionView) -> UICollectionViewDiffableDataSource<BuyListSection, AnyHashable> {
    .init(collectionView: collectionView) { [weak self] collectionView, indexPath, itemIdentifier in
      guard let self = self else { return UICollectionViewCell() }
      switch itemIdentifier {
      case let model as BuyListServiceCell.Model:
        return self.getServiceCell(collectionView: collectionView,
                                   indexPath: indexPath,
                                   model: model)
      default:
        return UICollectionViewCell()
      }
    }
  }
  
  func getServiceCell(collectionView: UICollectionView,
                      indexPath: IndexPath,
                      model: BuyListServiceCell.Model) -> UICollectionViewCell {
    guard let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: BuyListServiceCell.reuseIdentifier,
      for: indexPath) as? BuyListServiceCell else {
      return UICollectionViewCell()
    }
    
    cell.imageLoader = imageLoader
    cell.configure(model: model)
    cell.isFirstCell = indexPath.item == 0
    cell.isLastCell = indexPath.item == sections[indexPath.section].items.count - 1
    cell.isInGroup = sections[indexPath.section].items.count > 1
    return cell
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

