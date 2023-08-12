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
  func activityListCollectionControllerLoadNextPage(_ collectionController: ActivityListCollectionController)
  func activityListCollectionControllerEventViewModel(for eventId: String) -> ActivityListCompositionTransactionCell.Model?
  func activityListCollectionControllerDidPullToRefresh(_ collectionController: ActivityListCollectionController)
}

final class ActivityListCollectionController: NSObject {
  var isShimmer = false
  
  var sections = [ActivityListSection]() {
    didSet {
      didUpdateSections()
    }
  }
  
  weak var delegate: ActivityListCollectionControllerDelegate?
  
  private weak var collectionView: UICollectionView?
  private var dataSource: UICollectionViewDiffableDataSource<ActivityListSection, String>?
  private let collectionLayoutConfigurator = ActivityListCollectionLayoutConfigurator()
  private let imageLoader = NukeImageLoader()
  
  init(collectionView: UICollectionView) {
    self.collectionView = collectionView
    super.init()
    let layout = collectionLayoutConfigurator.getLayout { [weak self] sectionIndex in
      guard let self = self else { return ActivityListSection(date: Date(), title: nil, items: []) }
      return self.sections[sectionIndex]
    }
    collectionView.delegate = self
    collectionView.setCollectionViewLayout(layout, animated: false)
    collectionView.register(ActivityListTransactionCell.self,
                            forCellWithReuseIdentifier: ActivityListTransactionCell.reuseIdentifier)
    collectionView.register(ActivityListCompositionTransactionCell.self,
                            forCellWithReuseIdentifier: ActivityListCompositionTransactionCell.reuseIdentifier)
    collectionView.register(ActivityListSectionHeaderView.self,
                            forSupplementaryViewOfKind: ActivityListSectionHeaderView.reuseIdentifier,
                            withReuseIdentifier: ActivityListSectionHeaderView.reuseIdentifier)
    collectionView.register(ActivityListShimmerCell.self,
                            forCellWithReuseIdentifier: ActivityListShimmerCell.reuseIdentifier)
    dataSource = createDataSource(collectionView: collectionView)
  }
}

private extension ActivityListCollectionController {
  func didUpdateSections() {
    Task {
      var snapshot = NSDiffableDataSourceSnapshot<ActivityListSection, String>()
      sections.forEach { section in
        snapshot.appendSections([section])
        snapshot.appendItems(section.items, toSection: section)
      }
      dataSource?.apply(snapshot, animatingDifferences: true)
    }
  }
  
  func createDataSource(collectionView: UICollectionView) -> UICollectionViewDiffableDataSource<ActivityListSection, String> {
    let dataSource = UICollectionViewDiffableDataSource<ActivityListSection, String>(collectionView: collectionView) { [weak self] collectionView, indexPath, itemIdentifier in
      guard let self = self else { return UICollectionViewCell() }
      guard !isShimmer else {
        let shimmerCell = collectionView.dequeueReusableCell(withReuseIdentifier: ActivityListShimmerCell.reuseIdentifier, for: indexPath)
        (shimmerCell as? ActivityListShimmerCell)?.startAnimation()
        return shimmerCell
      }
      guard let model = delegate?.activityListCollectionControllerEventViewModel(for: itemIdentifier) else { return UICollectionViewCell() }
      return self.getCompositionTransactionCell(collectionView: collectionView, indexPath: indexPath, model: model)
    }
    
    dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath -> UICollectionReusableView? in
      switch kind {
      case ActivityListSectionHeaderView.reuseIdentifier:
        guard let headerView = collectionView
          .dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: ActivityListSectionHeaderView.reuseIdentifier,
            for: indexPath
          ) as? ActivityListSectionHeaderView else { return nil }
        let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
        headerView.configure(model: .init(date: section.title, isLoading: self?.isShimmer ?? false))
        return headerView
      default:
        return nil
      }
    }
    
    return dataSource
  }
  
  func getCompositionTransactionCell(collectionView: UICollectionView,
                                     indexPath: IndexPath,
                                     model: ActivityListCompositionTransactionCell.Model) -> UICollectionViewCell {
    guard let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: ActivityListCompositionTransactionCell.reuseIdentifier,
      for: indexPath) as? ActivityListCompositionTransactionCell else {
      return UICollectionViewCell()
    }
    
    cell.imageLoader = self.imageLoader
    cell.configure(model: model)
    return cell
  }
  
  func fetchNextIfNeeded(collectionView: UICollectionView, indexPath: IndexPath) {
    let numberOfSections = collectionView.numberOfSections
    let numberOfItems = collectionView.numberOfItems(inSection: numberOfSections - 1)
    guard indexPath.item == numberOfItems - 1 else { return }
    delegate?.activityListCollectionControllerLoadNextPage(self)
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
  
  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if scrollView.refreshControl?.isRefreshing == true {
      delegate?.activityListCollectionControllerDidPullToRefresh(self)
    }
  }
  
  func collectionView(_ collectionView: UICollectionView,
                      willDisplay cell: UICollectionViewCell,
                      forItemAt indexPath: IndexPath) {
    fetchNextIfNeeded(collectionView: collectionView, indexPath: indexPath)
  }
}
