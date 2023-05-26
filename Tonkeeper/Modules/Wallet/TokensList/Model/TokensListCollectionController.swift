//
//  TokensListCollectionController.swift
//  Tonkeeper
//
//  Created by Grigory on 26.5.23..
//

import UIKit

final class TokensListCollectionController {
  
  var sections = [TokensListSection]() {
    didSet {
      didUpdateSections()
    }
  }
  
  weak var collectionView: UICollectionView?
  var dataSource: UICollectionViewDiffableDataSource<TokensListSection.SectionType, AnyHashable>?
  
  init(collectionView: UICollectionView) {
    self.collectionView = collectionView
    dataSource = createDataSource(collectionView: collectionView)
  }
}

private extension TokensListCollectionController {
  func didUpdateSections() {
    var snapshot = NSDiffableDataSourceSnapshot<TokensListSection.SectionType, AnyHashable>()
    sections.forEach { section in
      snapshot.appendSections([section.type])
      snapshot.appendItems(section.items,toSection: section.type)
    }
    dataSource?.apply(snapshot)
  }
  
  func createDataSource(collectionView: UICollectionView) -> UICollectionViewDiffableDataSource<TokensListSection.SectionType, AnyHashable> {
    .init(collectionView: collectionView) { [weak self] collectionView, indexPath, itemIdentifier in
      guard let self = self else { return UICollectionViewCell() }
      switch itemIdentifier {
      case let tokenModel as TokenListTokenCell.Model:
        return self.getTokenCell(collectionView: collectionView,
                                 indexPath: indexPath,
                                 model: tokenModel)
      default:
        return UICollectionViewCell()
      }
    }
  }
  
  func getTokenCell(collectionView: UICollectionView,
                    indexPath: IndexPath,
                    model: TokenListTokenCell.Model) -> UICollectionViewCell {
    guard let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: TokenListTokenCell.reuseIdentifier,
      for: indexPath) as? TokenListTokenCell else {
      return UICollectionViewCell()
    }
    cell.configure(model: model)
    return cell
  }
}
