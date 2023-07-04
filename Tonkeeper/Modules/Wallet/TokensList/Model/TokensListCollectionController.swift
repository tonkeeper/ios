//
//  TokensListCollectionController.swift
//  Tonkeeper
//
//  Created by Grigory on 26.5.23..
//

import UIKit

final class TokensListCollectionController: NSObject {
  
  var sections = [TokensListSection]() {
    didSet {
      didUpdateSections()
    }
  }
  
  weak var collectionView: UICollectionView?
  var dataSource: UICollectionViewDiffableDataSource<TokensListSection.SectionType, AnyHashable>?
  
  private let collectionLayoutConfigurator = TokensListCollectionLayoutConfigurator()
  
  private let imageLoader: ImageLoader

  init(collectionView: UICollectionView,
       imageLoader: ImageLoader) {
    self.collectionView = collectionView
    self.imageLoader = imageLoader
    super.init()
    let layout = collectionLayoutConfigurator.getLayout { [weak self] sectionIndex in
      guard let self = self else { return .token }
      return self.sections[sectionIndex].type
    }
    
    collectionView.delegate = self
    collectionView.prefetchDataSource = self
    collectionView.setCollectionViewLayout(layout, animated: false)
    dataSource = createDataSource(collectionView: collectionView)
    collectionView.register(TokenListTokenCell.self,
                            forCellWithReuseIdentifier: TokenListTokenCell.reuseIdentifier)
    collectionView.register(TokensListCollectibleCell.self,
                            forCellWithReuseIdentifier: TokensListCollectibleCell.reuseIdentifier)
  }
}

private extension TokensListCollectionController {
  func didUpdateSections() {
    var snapshot = NSDiffableDataSourceSnapshot<TokensListSection.SectionType, AnyHashable>()
    sections.forEach { section in
      snapshot.appendSections([section.type])
      snapshot.appendItems(section.items,toSection: section.type)
    }
    dataSource?.apply(snapshot, animatingDifferences: false)
  }
  
  func createDataSource(collectionView: UICollectionView) -> UICollectionViewDiffableDataSource<TokensListSection.SectionType, AnyHashable> {
    .init(collectionView: collectionView) { [weak self] collectionView, indexPath, itemIdentifier in
      guard let self = self else { return UICollectionViewCell() }
      switch itemIdentifier {
      case let tokenModel as TokenListTokenCell.Model:
        return self.getTokenCell(collectionView: collectionView,
                                 indexPath: indexPath,
                                 model: tokenModel)
      case let collectibleModel as TokensListCollectibleCell.Model:
        return self.getCollectibleCell(collectionView: collectionView,
                                       indexPath: indexPath,
                                       model: collectibleModel)
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
    cell.imageLoader = self.imageLoader
    cell.configure(model: model)
    cell.isFirstCell = indexPath.item == 0
    cell.isLastCell = indexPath.item == sections[indexPath.section].items.count - 1
    return cell
  }
  
  func getCollectibleCell(collectionView: UICollectionView,
                          indexPath: IndexPath,
                          model: TokensListCollectibleCell.Model) -> UICollectionViewCell {
    guard let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: TokensListCollectibleCell.reuseIdentifier,
      for: indexPath) as? TokensListCollectibleCell else {
      return UICollectionViewCell()
    }
    cell.imageLoader = self.imageLoader
    cell.configure(model: model)
    return cell
  }
}

extension TokensListCollectionController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    (collectionView.cellForItem(at: indexPath) as? Selectable)?.select()
    collectionView.deselectItem(at: indexPath, animated: true)
  }
  
  func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
    (collectionView.cellForItem(at: indexPath) as? Selectable)?.deselect()
  }
}

extension TokensListCollectionController: UICollectionViewDataSourcePrefetching {
  func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
    let urls = indexPaths.compactMap { indexPath -> URL? in
      guard let itemIdentifier = dataSource?.itemIdentifier(for: indexPath) else {
        return nil
      }
      
      switch itemIdentifier {
      case let tokenModel as TokenListTokenCell.Model:
        guard case let .url(url) = tokenModel.image else {
          return nil
        }
        return url
      case let collectibleModel as TokensListCollectibleCell.Model:
        guard case let .url(url) = collectibleModel.image else {
          return nil
        }
        return url
      default:
        return nil
      }
    }
    imageLoader.prefetchImages(imageURLs: urls)
  }
  
  func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
    let urls = indexPaths.compactMap { indexPath -> URL? in
      guard let itemIdentifier = dataSource?.itemIdentifier(for: indexPath) else {
        return nil
      }
      
      switch itemIdentifier {
      case let tokenModel as TokenListTokenCell.Model:
        guard case let .url(url) = tokenModel.image else {
          return nil
        }
        return url
      case let collectibleModel as TokensListCollectibleCell.Model:
        guard case let .url(url) = collectibleModel.image else {
          return nil
        }
        return url
      default:
        return nil
      }
    }
    imageLoader.stopPrefetchImages(imageURLs: urls)
  }
}
